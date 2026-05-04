import Foundation

// MARK: - AIServiceError

public enum AIServiceError: LocalizedError {
    case httpError(Int, String?)
    case emptyResponse
    case invalidJSON(String)
    case configurationError(String)

    public var errorDescription: String? {
        switch self {
        case .httpError(let code, let msg):
            return msg.map { "HTTP \(code)：\($0)" } ?? "HTTP 错误：\(code)"
        case .emptyResponse:
            return "AI 未返回有效内容"
        case .invalidJSON(let detail):
            return "JSON 解析失败：\(detail)"
        case .configurationError(let msg):
            return msg
        }
    }
}

// MARK: - OpenAI wire types (private)

private struct OpenAIChatRequest: Encodable {
    let model: String
    let messages: [Message]
    let temperature: Double

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

/// Outer OpenAI-compatible envelope:
/// `{ "choices": [ { "message": { "content": "<AI JSON string>" } } ] }`
///
/// Step 1 of the two-step decode: unwrap the envelope and extract the raw
/// content string before any further parsing.
private struct APIWrapperResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String
    }
}

// MARK: - AI response payload (drug rules)

/// Maps the top-level JSON structure the AI returns:
/// `{ "drug": { … }, "rules": [ … ] }`
///
/// Both nested types are decoded directly into the canonical model types
/// (`AnesthesiaDrug` and `DosageRule`) — no extra intermediate structs needed.
public struct AIDrugResponse: Codable {
    public let drug: AnesthesiaDrug
    public let rules: [DosageRule]
}

// MARK: - AI response payload (medical Q&A)

/// Maps the JSON the Q&A AI returns:
/// `{ "answer": "…", "category": "药理机制" }`
public struct AIQAResponse: Codable {
    public var answer: String
    public var category: String?
}

// MARK: - AI response payload (decision plan)

/// Maps the structured JSON that the decision AI returns:
/// ```json
/// {
///   "patient": { "name": "…", "age": "…", "surgery": "…", "conditions": […] },
///   "plan": "…"
/// }
/// ```
public struct AIDecisionResponse: Codable {
    public struct PatientInfo: Codable {
        public var name: String
        public var hospitalNumber: String
        public var age: String
        public var surgery: String
        public var conditions: [String]
    }
    public var patient: PatientInfo
    public var plan: String
}

// MARK: - AIAssistantService

/// Calls an OpenAI-compatible chat API to generate dosage rules for a named drug.
///
/// Configuration is read at call time from `UserDefaults` using the following keys:
/// - `ai_api_url`       — full completions endpoint URL
/// - `ai_api_key`       — Bearer token
/// - `ai_model_name`    — model identifier
/// - `ai_system_prompt` — system message sent before the user query
///
/// If `ai_api_key` is empty or `ai_api_url` is not a valid HTTP(S) URL, a
/// `AIServiceError.configurationError` is thrown before any network call is made.
///
/// ## Usage
/// ```swift
/// let (drug, rules) = try await AIAssistantService.shared.fetchDrugRules(for: "右美托咪定")
/// DrugManager.shared.activeDrugs.append(drug)
/// AIRuleEngine.shared.replaceAllRules(with: AIRuleEngine.shared.allRules + rules)
/// ```
public final class AIAssistantService {

    public static let shared = AIAssistantService()

    private init() {}

    // ══════════════════════════════════════════════════════════════════
    // MARK: — Public API
    // ══════════════════════════════════════════════════════════════════

    /// Queries the AI to generate an `AnesthesiaDrug` and its associated `[DosageRule]`
    /// for the given drug name, using authoritative anaesthesia guidelines as context.
    ///
    /// - Parameter drugName: The drug to look up, e.g. "右美托咪定" or "dexmedetomidine".
    /// - Returns: A tuple of the new drug value and its ready-to-register dosage rules.
    /// - Throws: `AIServiceError` on configuration/network/HTTP/parse failure; `URLError` on timeout.
    public func fetchDrugRules(
        for drugName: String
    ) async throws -> (drug: AnesthesiaDrug, rules: [DosageRule]) {

        let defaults = UserDefaults.standard

        let urlString  = defaults.string(forKey: "ai_api_url")    ?? ""
        let apiKey     = defaults.string(forKey: "ai_api_key")    ?? ""
        let modelName  = defaults.string(forKey: "ai_model_name") ?? "gpt-4o-mini"
        let rawPrompt  = defaults.string(forKey: "ai_system_prompt") ?? ""
        let sysPrompt  = rawPrompt.isEmpty ? Self.defaultSystemPrompt : rawPrompt

        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIServiceError.configurationError("请先在「AI 模型与接口设置」中配置 API 密钥")
        }

        let normalizedURLString: String = {
            let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            let suffix = "/chat/completions"
            return trimmed.hasSuffix(suffix) ? trimmed : trimmed.trimmingCharacters(in: ["/"]) + suffix
        }()

        guard
            let url = URL(string: normalizedURLString),
            url.scheme?.hasPrefix("http") == true,
            url.host != nil
        else {
            throw AIServiceError.configurationError("请先在「AI 模型与接口设置」中配置有效的 API 接口地址")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json",  forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let body = OpenAIChatRequest(
            model: modelName,
            messages: [
                .init(role: "system", content: sysPrompt),
                .init(role: "user",   content: "请为以下麻醉药物生成标准剂量规则：\(drugName)")
            ],
            temperature: 0.1
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AIServiceError.httpError(0, nil)
        }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8)
            throw AIServiceError.httpError(http.statusCode, body)
        }

        // ── Step 1: unwrap the outer OpenAI envelope ──────────────────
        let apiResponse = try JSONDecoder().decode(APIWrapperResponse.self, from: data)
        let rawContent  = apiResponse.choices.first?.message.content ?? ""

        print("AI Raw Response: \(rawContent)")

        guard !rawContent.isEmpty else {
            throw AIServiceError.emptyResponse
        }

        // ── Step 2: sanitise — strip <think> blocks & Markdown fences ─
        let cleanedString = sanitizeResponse(rawContent)

        guard !cleanedString.isEmpty else {
            throw AIServiceError.invalidJSON("AI 返回内容为空")
        }

        // ── Step 3: convert cleaned string back to Data ────────────────
        guard let cleanData = cleanedString.data(using: .utf8) else {
            throw AIServiceError.invalidJSON("无法将内容转换为 UTF-8 数据")
        }

        // ── Step 4: decode the inner AIDrugResponse payload ───────────
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let finalResult: AIDrugResponse
        do {
            finalResult = try decoder.decode(AIDrugResponse.self, from: cleanData)
        } catch let DecodingError.dataCorrupted(context) {
            print("DecodingError.dataCorrupted:", context)
            throw AIServiceError.invalidJSON("数据损坏：\(context.debugDescription)")
        } catch let DecodingError.keyNotFound(key, context) {
            print("DecodingError.keyNotFound: key '\(key.stringValue)'", context.debugDescription)
            throw AIServiceError.invalidJSON("缺少字段 '\(key.stringValue)'：\(context.debugDescription)")
        } catch let DecodingError.valueNotFound(type, context) {
            print("DecodingError.valueNotFound: type '\(type)'", context.debugDescription)
            throw AIServiceError.invalidJSON("字段值为空（\(type)）：\(context.debugDescription)")
        } catch let DecodingError.typeMismatch(type, context) {
            print("DecodingError.typeMismatch: type '\(type)'", context.debugDescription)
            throw AIServiceError.invalidJSON("类型不匹配（\(type)）：\(context.debugDescription)")
        } catch {
            print("DecodingError (other):", error)
            throw AIServiceError.invalidJSON(error.localizedDescription)
        }

        // Back-fill fields the AI sometimes omits from individual rule objects
        // to reduce token count, deriving them from the outer `drug` envelope.
        var completeRules = finalResult.rules
        for i in 0..<completeRules.count {
            completeRules[i].drug = finalResult.drug.name
            // AI may omit concentrationMgPerMl when it matches defaultConcentration;
            // 0 is the sentinel set by decodeIfPresent fallback.
            if completeRules[i].concentrationMgPerMl == 0 {
                completeRules[i].concentrationMgPerMl = finalResult.drug.defaultConcentration
            }
        }
        return (finalResult.drug, completeRules)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: — Private helpers
    // ══════════════════════════════════════════════════════════════════

    /// Removes `<think>…</think>` reasoning blocks, markdown fences, and surrounding
    /// whitespace from a raw model response, leaving only the JSON payload.
    private func sanitizeResponse(_ raw: String) -> String {
        var s = raw

        // Strip <think>…</think> blocks (DeepSeek-R1 / o1-style reasoning traces)
        if let regex = try? NSRegularExpression(
            pattern: #"<think>[\s\S]*?</think>"#,
            options: .caseInsensitive
        ) {
            let range = NSRange(s.startIndex..., in: s)
            s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "")
        }

        s = s.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip opening markdown fence (```json or ```)
        if let range = s.range(of: "```json") {
            s = String(s[range.upperBound...])
        } else if let range = s.range(of: "```") {
            s = String(s[range.upperBound...])
        }

        // Strip closing markdown fence
        if let range = s.range(of: "```", options: .backwards) {
            s = String(s[..<range.lowerBound])
        }

        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }


    // ══════════════════════════════════════════════════════════════════
    // MARK: — Decision Plan API
    // ══════════════════════════════════════════════════════════════════

    /// Sends combined free-text + structured patient info to the AI and returns
    /// a structured `AIDecisionResponse` containing extracted patient data and
    /// a concise anaesthesia plan.
    ///
    /// - Parameter combinedInput: Concatenated free-text description and any
    ///   structured fields the user filled in (name, age, surgery, conditions).
    /// - Returns: A decoded `AIDecisionResponse`.
    /// - Throws: `AIServiceError` on configuration/network/HTTP/parse failure.
    public func fetchDecisionPlan(combinedInput: String) async throws -> AIDecisionResponse {

        let defaults   = UserDefaults.standard
        let urlString  = defaults.string(forKey: "ai_api_url")    ?? ""
        let apiKey     = defaults.string(forKey: "ai_api_key")    ?? ""
        let modelName  = defaults.string(forKey: "ai_model_name") ?? "gpt-4o-mini"

        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIServiceError.configurationError("请先在「AI 模型与接口设置」中配置 API 密钥")
        }

        let normalizedURLString: String = {
            let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            let suffix  = "/chat/completions"
            return trimmed.hasSuffix(suffix) ? trimmed : trimmed.trimmingCharacters(in: ["/"]) + suffix
        }()

        guard
            let url = URL(string: normalizedURLString),
            url.scheme?.hasPrefix("http") == true,
            url.host != nil
        else {
            throw AIServiceError.configurationError("请先在「AI 模型与接口设置」中配置有效的 API 接口地址")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json",  forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let rawDecisionPrompt = defaults.string(forKey: "ai_decision_prompt") ?? ""
        let sysDecisionPrompt = rawDecisionPrompt.isEmpty ? Self.decisionSystemPrompt : rawDecisionPrompt

        let body = OpenAIChatRequest(
            model: modelName,
            messages: [
                .init(role: "system", content: sysDecisionPrompt),
                .init(role: "user",   content: combinedInput)
            ],
            temperature: 0.3
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AIServiceError.httpError(0, nil)
        }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8)
            throw AIServiceError.httpError(http.statusCode, body)
        }

        let apiResponse = try JSONDecoder().decode(APIWrapperResponse.self, from: data)
        let rawContent  = apiResponse.choices.first?.message.content ?? ""
        print("[AIDecision] Raw Response: \(rawContent)")

        guard !rawContent.isEmpty else { throw AIServiceError.emptyResponse }

        let cleaned = sanitizeResponse(rawContent)
        guard !cleaned.isEmpty, let cleanData = cleaned.data(using: .utf8) else {
            throw AIServiceError.invalidJSON("AI 决策响应内容为空或无法解码")
        }

        do {
            return try JSONDecoder().decode(AIDecisionResponse.self, from: cleanData)
        } catch {
            throw AIServiceError.invalidJSON(error.localizedDescription)
        }
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: — Medical Q&A API
    // ══════════════════════════════════════════════════════════════════

    /// Sends a free-form medical question to the AI and returns a structured
    /// `AIQAResponse` containing a full answer and an optional category tag.
    ///
    /// - Parameter question: The user's medical question in any language.
    /// - Returns: A decoded `AIQAResponse`.
    /// - Throws: `AIServiceError` on configuration/network/HTTP/parse failure.
    public func fetchMedicalAnswer(question: String) async throws -> AIQAResponse {

        let defaults  = UserDefaults.standard
        let urlString = defaults.string(forKey: "ai_api_url")    ?? ""
        let apiKey    = defaults.string(forKey: "ai_api_key")    ?? ""
        let modelName = defaults.string(forKey: "ai_model_name") ?? "gpt-4o-mini"

        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIServiceError.configurationError("请先在「AI 模型与接口设置」中配置 API 密钥")
        }

        let normalizedURLString: String = {
            let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            let suffix  = "/chat/completions"
            return trimmed.hasSuffix(suffix) ? trimmed : trimmed.trimmingCharacters(in: ["/"]) + suffix
        }()

        guard
            let url = URL(string: normalizedURLString),
            url.scheme?.hasPrefix("http") == true,
            url.host != nil
        else {
            throw AIServiceError.configurationError("请先在「AI 模型与接口设置」中配置有效的 API 接口地址")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json",  forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let rawQAPrompt = defaults.string(forKey: "ai_qa_prompt") ?? ""
        let sysQAPrompt = rawQAPrompt.isEmpty ? Self.medicalQASystemPrompt : rawQAPrompt

        let body = OpenAIChatRequest(
            model: modelName,
            messages: [
                .init(role: "system", content: sysQAPrompt),
                .init(role: "user",   content: question)
            ],
            temperature: 0.4
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AIServiceError.httpError(0, nil)
        }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8)
            throw AIServiceError.httpError(http.statusCode, body)
        }

        let apiResponse = try JSONDecoder().decode(APIWrapperResponse.self, from: data)
        let rawContent  = apiResponse.choices.first?.message.content ?? ""
        print("[MedicalQA] Raw Response: \(rawContent)")

        guard !rawContent.isEmpty else { throw AIServiceError.emptyResponse }

        let cleaned = sanitizeResponse(rawContent)
        guard !cleaned.isEmpty, let cleanData = cleaned.data(using: .utf8) else {
            throw AIServiceError.invalidJSON("问答响应内容为空或无法解码")
        }

        do {
            return try JSONDecoder().decode(AIQAResponse.self, from: cleanData)
        } catch {
            throw AIServiceError.invalidJSON(error.localizedDescription)
        }
    }

    // ── Medical Q&A system prompt ──────────────────────────────────────

    static let medicalQASystemPrompt = """
    你是一位顶级的医学顾问，精通麻醉学、重症医学、药理学及临床急救医学，拥有丰富的三甲医院临床经验。

    任务：根据用户提出的医学问题，给出准确、专业、简洁的回答。

    严格要求：
    1. 你必须且只能返回一段合法的 JSON 字符串。
    2. 不得包含任何 markdown 标记（如 ```json）、解释文字、注释或任何 JSON 结构以外的内容。
    3. answer 字段用中文回答，内容专业但易于理解，允许适当分段（换行用 \\n），不超过 500 字。
    4. category 字段为该问题的简短分类标签（2-5个汉字），例如：药理机制、剂量计算、突发应急、术前评估、气道管理、并发症处理、监测指标。如无法归类，填 null。

    必须严格按照以下 JSON 结构返回，不得增减顶层字段：
    {
      "answer": "完整的医学回答",
      "category": "分类标签或null"
    }
    """

    // ── Decision system prompt ─────────────────────────────────────────

    static let decisionSystemPrompt = """
    你是一位资深麻醉科主任，拥有超过 20 年的临床麻醉经验，熟悉最新 ASA 与中华医学会麻醉学分会指南。

    任务：分析用户提供的患者信息（可能是自由文本，也可能是结构化字段，或两者混合），提取关键信息，并生成一份精简、专业的麻醉计划。

    严格要求：
    1. 你必须且只能返回一段合法的 JSON 字符串。
    2. 不得包含任何 markdown 标记（如 ```json）、解释文字、注释或任何 JSON 结构以外的内容。
    3. 患者姓名若无法从输入中提取，填「佚名」。
    4. 请尝试从用户的输入中提取患者的"住院号"（通常为8位左右的数字），并放入 JSON 的 hospitalNumber 字段。如果没有提供，则返回空字符串 ""。
    5. conditions 数组只包含有临床麻醉意义的既往史与异常情况（如「高血压」「糖尿病」「困难气道」）。
    6. plan 字段使用简洁、专业的临床语言，分段叙述（换行用 \\n），不超过 300 字。

    必须严格按照以下 JSON 结构返回，不得增减顶层字段：
    {
      "patient": {
        "name": "患者姓名",
        "hospitalNumber": "住院号（如有，否则为空字符串）",
        "age": "年龄（如 45岁）",
        "surgery": "手术名称",
        "conditions": ["既往史/异常情况"]
      },
      "plan": "麻醉计划正文"
    }
    """

    // ══════════════════════════════════════════════════════════════════
    // MARK: — Default System Prompt (drug rules)

    /// Used as fallback when `UserDefaults` key `ai_system_prompt` is absent or empty.
    static let defaultSystemPrompt = """
    你是一位资深的三甲医院麻醉科主治医师，具有丰富的临床经验和深厚的药理学知识。
    你的任务是根据最新的临床麻醉指南（包括但不限于：ASA 指南、中华医学会麻醉学分会指南、\
    欧洲麻醉学会 ESAIC 指南、各药物的官方说明书 SmPC/PI），为用户指定的麻醉药物生成精准的剂量计算规则。

    **严格要求：**
    1. 你必须且只能返回一段合法的 JSON 字符串。
    2. 不得包含任何 markdown 标记（如 ```json）、解释文字、注释或任何 JSON 结构以外的内容。
    3. JSON 中的所有数值必须是合法的 JSON 数字（不得使用字符串表示数值）。
    4. 极其重要："doseType" 的值必须且只能从以下纯中文词汇中选择：["诱导", "维持", "插管", "镇痛", "镇静", "拮抗"]。\
    绝不允许输出任何英文或下划线格式（如 induction、induction_analgesia），否则将导致系统解析崩溃！
    5. "weightBase" 的值只能是：TBW（实际体重）、IBW（理想体重）、LBW（去脂体重）之一。
    6. "unit" 的值只能是：mg 或 mcg。
    7. "doseInterval" 的值只能是：bolus（单次推注）、perHour（每小时输注速率）、perMinute（每分钟输注速率）之一。
    8. 请根据该药物的临床适应症，尽可能完整地覆盖所有适用的 doseType。
    9. "ageAdjustments" 中的 "scalingFactor" 必须是大于 0 且小于等于 1 的小数（只减量不增量）。
    10. 若某项可选字段（absoluteMaxDose、ageAdjustments）不适用，直接省略该字段，不要写 null。

    你必须严格按照以下 JSON 结构返回，不得增减顶层字段：

    {
      "drug": {
        "id": "全局唯一的 UUID 字符串（格式：xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx）",
        "name": "药物中文名 (英文名)",
        "defaultConcentration": 市售最常用制剂浓度（mg/mL，纯数字）,
        "concentrationUnit": "mg/mL"
      },
      "rules": [
        {
          "drug": "与 drug.name 完全相同的字符串",
          "doseType": "上述六个中文值之一（诱导/维持/插管/镇痛/镇静/拮抗）",
          "minMultiplier": 最小剂量（每kg体重对应的unit数量，纯数字）,
          "maxMultiplier": 最大剂量（每kg体重对应的unit数量，纯数字）,
          "weightBase": "TBW / IBW / LBW 之一",
          "unit": "mg 或 mcg",
          "concentrationMgPerMl": 制剂浓度（mg/mL，纯数字，必填）,
          "absoluteMaxDose": 单次/次给药安全上限（纯数字，可选，不适用则省略）,
          "ageAdjustments": [
            { "ageThreshold": 触发年龄阈值（整数）, "scalingFactor": 剂量缩减系数（0~1小数） }
          ],
          "doseInterval": "bolus / perHour / perMinute 之一"
        }
      ]
    }
    """
}
