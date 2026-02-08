//
//  AdInterstitialManager.swift
//  A4PrintPDF
//

#if canImport(UIKit)
import GoogleMobileAds
import UIKit

@Observable
final class AdInterstitialManager: NSObject, FullScreenContentDelegate {
    private var interstitialAd: InterstitialAd?
    private var completion: (() -> Void)?

    // テスト用 Ad Unit ID（本番リリース時に差し替え）
    private let adUnitID = "ca-app-pub-4319862060540319/7360408120"

    func loadAd() {
        InterstitialAd.load(with: adUnitID, request: Request()) { [weak self] ad, error in
            guard let self else { return }
            if let error {
                print("Ad load failed: \(error.localizedDescription)")
                return
            }
            interstitialAd = ad
            interstitialAd?.fullScreenContentDelegate = self
        }
    }

    func showAd(completion: @escaping () -> Void) {
        guard let interstitialAd,
              let rootVC = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)?
                .rootViewController else {
            completion()
            return
        }

        self.completion = completion
        interstitialAd.present(from: rootVC)
    }

    // MARK: - FullScreenContentDelegate

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        MainActor.assumeIsolated {
            interstitialAd = nil
            completion?()
            completion = nil
            loadAd()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        MainActor.assumeIsolated {
            print("Ad present failed: \(error.localizedDescription)")
            interstitialAd = nil
            completion?()
            completion = nil
            loadAd()
        }
    }
}
#endif
