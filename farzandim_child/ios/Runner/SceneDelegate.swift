import Flutter
import UIKit

/// UIScene oynasi AppDelegate'da OLDINDAN yaratilgan `flutterEngine` bilan
/// quriladi (storyboard'dagi implicit engine emas — sababi AppDelegate.swift
/// izohida). Scene hodisalari Flutter plaginlariga
/// `FlutterPluginSceneLifeCycleDelegate` orqali uzatiladi (FlutterSceneDelegate
/// bilan bir xil vazifa).
class SceneDelegate: UIResponder, UIWindowSceneDelegate, FlutterSceneLifeCycleProvider {
  var window: UIWindow?
  let sceneLifeCycleDelegate = FlutterPluginSceneLifeCycleDelegate()

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard
      let windowScene = scene as? UIWindowScene,
      let appDelegate = UIApplication.shared.delegate as? AppDelegate
    else { return }
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = FlutterViewController(
      engine: appDelegate.flutterEngine,
      nibName: nil,
      bundle: nil
    )
    self.window = window
    window.makeKeyAndVisible()
    sceneLifeCycleDelegate.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  func sceneDidDisconnect(_ scene: UIScene) {
    sceneLifeCycleDelegate.sceneDidDisconnect(scene)
  }

  func sceneWillEnterForeground(_ scene: UIScene) {
    sceneLifeCycleDelegate.sceneWillEnterForeground(scene)
  }

  func sceneDidBecomeActive(_ scene: UIScene) {
    sceneLifeCycleDelegate.sceneDidBecomeActive(scene)
  }

  func sceneWillResignActive(_ scene: UIScene) {
    sceneLifeCycleDelegate.sceneWillResignActive(scene)
  }

  func sceneDidEnterBackground(_ scene: UIScene) {
    sceneLifeCycleDelegate.sceneDidEnterBackground(scene)
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    sceneLifeCycleDelegate.scene(scene, openURLContexts: URLContexts)
  }

  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    sceneLifeCycleDelegate.scene(scene, continue: userActivity)
  }

  func windowScene(
    _ windowScene: UIWindowScene,
    performActionFor shortcutItem: UIApplicationShortcutItem,
    completionHandler: @escaping (Bool) -> Void
  ) {
    sceneLifeCycleDelegate.windowScene(
      windowScene,
      performActionFor: shortcutItem,
      completionHandler: completionHandler
    )
  }
}
