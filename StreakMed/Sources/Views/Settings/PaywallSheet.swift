import SwiftUI
import StoreKit

/// StreakMed Plus paywall. Presented from Settings and from any gated feature.
/// Everything health-critical stays free; this only sells the extras.
struct PaywallSheet: View {
    @EnvironmentObject var plus: PlusStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedID: String = PlusStore.ProductID.yearly
    @State private var showError = false

    private let eulaURL    = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private let privacyURL = URL(string: "https://www.notion.so/StreakMed-Privacy-Policy-323dc81e319480a5b5aae7e30543a7f2")!

    private var selected: Product? { plus.products.first { $0.id == selectedID } }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AppTheme.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    header
                    featureList
                    plans
                    cta
                    footer
                }
                .padding(.horizontal, 24)
                .padding(.top, 36)
                .padding(.bottom, 32)
            }

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.textMuted)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.surfaceAlt)
                    .clipShape(Circle())
            }
            .padding(.top, 16)
            .padding(.trailing, 20)
        }
        .onChange(of: plus.lastError) { err in showError = err != nil }
        .alert("Something went wrong", isPresented: $showError) {
            Button("OK") { plus.lastError = nil }
        } message: {
            Text(plus.lastError ?? "")
        }
        .task { await plus.loadProducts() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.accentDim)
                    .frame(width: 72, height: 72)
                Image(systemName: "sparkles")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
            }
            Text("StreakMed Plus")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(AppTheme.text)
                .tracking(-0.5)
            Text("Reminders, streaks, widgets and Health import stay free for everyone. Plus adds the extras and keeps StreakMed ad-free.")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Features

    private var featureList: some View {
        VStack(spacing: 0) {
            featureRow(icon: "arrow.up.doc.fill",       title: "Export your history",
                       sub: "CSV or PDF of every logged dose — handy for appointments")
            Divider().background(AppTheme.border)
            featureRow(icon: "chart.bar.doc.horizontal", title: "Adherence reports",
                       sub: "Per-medication breakdown for the last 30 days")
            Divider().background(AppTheme.border)
            featureRow(icon: "paintpalette.fill",        title: "Accent themes",
                       sub: "Five colour themes for light and dark mode")
            Divider().background(AppTheme.border)
            featureRow(icon: "heart.fill",               title: "Support an indie developer",
                       sub: "No ads, no tracking, no accounts — ever")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
        .background(AppTheme.surface)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.border, lineWidth: 1))
    }

    private func featureRow(icon: String, title: String, sub: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppTheme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.text)
                Text(sub)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Plans

    @ViewBuilder
    private var plans: some View {
        if plus.products.isEmpty {
            VStack(spacing: 10) {
                if plus.isLoadingProducts {
                    ProgressView().tint(AppTheme.accent)
                    Text("Loading plans…")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textMuted)
                } else {
                    Text("Plans aren't available right now.")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textMuted)
                    Button("Try again") { Task { await plus.loadProducts() } }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.accent)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        } else {
            VStack(spacing: 10) {
                if let yearly = plus.yearly {
                    PlanCard(product: yearly, badge: "Best value", caption: yearlyCaption(yearly),
                             isSelected: selectedID == yearly.id) { selectedID = yearly.id }
                }
                if let monthly = plus.monthly {
                    PlanCard(product: monthly, badge: nil, caption: "Billed monthly · cancel anytime",
                             isSelected: selectedID == monthly.id) { selectedID = monthly.id }
                }
                if let lifetime = plus.lifetime {
                    PlanCard(product: lifetime, badge: nil, caption: "One-time purchase · yours forever",
                             isSelected: selectedID == lifetime.id) { selectedID = lifetime.id }
                }
            }
        }
    }

    private func yearlyCaption(_ product: Product) -> String {
        var parts: [String] = []
        if let trial = trialDescription(product) { parts.append(trial) }
        let perMonth = (product.price / 12).formatted(product.priceFormatStyle)
        parts.append("\(perMonth)/month")
        return parts.joined(separator: " · ")
    }

    /// "7-day free trial" if the product carries a free-trial intro offer.
    private func trialDescription(_ product: Product) -> String? {
        guard let offer = product.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        let p = offer.period
        let unit: String
        switch p.unit {
        case .day:   unit = p.value == 7 ? "7-day" : "\(p.value)-day"
        case .week:  unit = p.value == 1 ? "7-day" : "\(p.value)-week"
        case .month: unit = p.value == 1 ? "1-month" : "\(p.value)-month"
        case .year:  unit = "\(p.value)-year"
        @unknown default: unit = ""
        }
        return "\(unit) free trial"
    }

    // MARK: - CTA

    private var ctaTitle: String {
        guard let product = selected else { return "Continue" }
        if trialDescription(product) != nil { return "Start Free Trial" }
        return product.type == .nonConsumable ? "Buy Lifetime — \(product.displayPrice)" : "Subscribe — \(product.displayPrice)"
    }

    private var cta: some View {
        VStack(spacing: 10) {
            Button {
                guard let product = selected else { return }
                Task {
                    if await plus.purchase(product) {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    }
                }
            } label: {
                HStack {
                    if plus.isPurchasing {
                        ProgressView().tint(AppTheme.accentFG)
                    } else {
                        Text(ctaTitle)
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .foregroundColor(AppTheme.accentFG)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.accent)
                .cornerRadius(16)
            }
            .disabled(selected == nil || plus.isPurchasing)
            .opacity(selected == nil ? 0.5 : 1)

            if let product = selected, let trial = trialDescription(product) {
                Text("\(trial), then \(product.displayPrice)/year. Cancel anytime in Settings.")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textDim)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                Task { await plus.restore(); if plus.isPlus { dismiss() } }
            } label: {
                Text("Restore Purchases")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.textMuted)
            }

            HStack(spacing: 16) {
                Link("Terms of Use", destination: eulaURL)
                Link("Privacy Policy", destination: privacyURL)
            }
            .font(.system(size: 12))
            .foregroundColor(AppTheme.textDim)

            Text("Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel in your Apple Account settings.")
                .font(.system(size: 10))
                .foregroundColor(AppTheme.textDim)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Plan card

private struct PlanCard: View {
    let product: Product
    let badge: String?
    let caption: String
    let isSelected: Bool
    let onTap: () -> Void

    private var periodSuffix: String {
        guard let sub = product.subscription else { return "" }
        switch sub.subscriptionPeriod.unit {
        case .month: return "/mo"
        case .year:  return "/yr"
        case .week:  return "/wk"
        case .day:   return "/day"
        @unknown default: return ""
        }
    }

    private var title: String {
        if product.type == .nonConsumable { return "Lifetime" }
        switch product.subscription?.subscriptionPeriod.unit {
        case .year:  return "Yearly"
        case .month: return "Monthly"
        default:     return product.displayName
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? AppTheme.accent : AppTheme.border, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(AppTheme.accent).frame(width: 12, height: 12)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.text)
                        if let badge {
                            Text(badge.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .tracking(0.5)
                                .foregroundColor(AppTheme.accentFG)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(AppTheme.accent)
                                .cornerRadius(5)
                        }
                    }
                    Text(caption)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer(minLength: 8)
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(product.displayPrice)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(AppTheme.text)
                    Text(periodSuffix)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                }
            }
            .padding(16)
            .background(isSelected ? AppTheme.accentDim : AppTheme.surface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? AppTheme.accent : AppTheme.border, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
