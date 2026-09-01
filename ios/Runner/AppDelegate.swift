import Flutter
import StoreKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let storeKitChannel = FlutterMethodChannel(
      name: "com.miyaapps.sizeyoho/storekit",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    storeKitChannel.setMethodCallHandler { call, result in
      guard call.method == "currentEntitlements" else {
        result(FlutterMethodNotImplemented)
        return
      }

      // Transaction.currentEntitlementsが返す検証済み権利をそのまま採用する。
      // expirationDateを追加判定するとBilling Grace Period中の利用者を
      // 誤って失効扱いにし得るため、StoreKitの権利判定を上書きしない。
      Task {
        var productIDs: [String] = []
        for await verificationResult in Transaction.currentEntitlements {
          guard case .verified(let transaction) = verificationResult else {
            continue
          }
          productIDs.append(transaction.productID)
        }
        await MainActor.run {
          result(productIDs)
        }
      }
    }
  }
}
