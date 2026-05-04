import SwiftUI
import AnesthesiaCalcCore

// MARK: - MonitorAlert

struct MonitorAlert: Equatable {
    let message: String
    let prefillQuestion: String
}

// MARK: - ActiveMonitor

enum ActiveMonitor {
    /// Evaluate clinical rules and return an alert if any trigger.
    static func check(patient: Patient?, drugs: [AnesthesiaDrug]) -> MonitorAlert? {
        guard let p = patient else { return nil }

        // Rule 1: age > 80 + propofol → circulatory warning
        if p.age > 80 && drugs.contains(where: { $0.name == "丙泊酚" }) {
            return MonitorAlert(
                message: "高龄患者注意循环波动，点击查看指南建议",
                prefillQuestion: "高龄患者（\(p.age)岁）使用丙泊酚的注意事项、剂量调整及循环监测建议"
            )
        }

        return nil
    }
}

// MARK: - ActiveMonitorBanner

/// 顶部吸顶提示条 — 淡橙色背景，lightbulb.fill 图标。
/// 主点击：打开 ConsultView 发起指南检索。
/// 辅助点击（米勒按钮）：打开 ConsultView 并预填机制解析问题。
struct ActiveMonitorBanner: View {
    let alert: MonitorAlert
    let action: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // 主操作区：指南咨询
            Button(action: action) {
                HStack(spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    Text(alert.message)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.orange)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}
