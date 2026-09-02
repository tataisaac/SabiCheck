//
//  ShareViewController.swift
//  SabiCheck Share Extension
//
//  Receives text / URLs / images from the iOS share sheet (WhatsApp, Messages,
//  Photos, Safari…) and hands them to the SabiCheck app via the App Group,
//  courtesy of the receive_sharing_intent plugin.
//
//  NOTE: This file is NOT wired into the Xcode project yet — a Share Extension
//  target must be created in Xcode on a Mac (File → New → Target → Share
//  Extension, product name "ShareExtension"). Follow docs/IOS_SHARE_EXTENSION.md,
//  then replace the generated ShareViewController.swift with this one.
//
import receive_sharing_intent

class ShareViewController: RSIShareViewController {

    // Jump straight into SabiCheck with the content pre-filled — "two taps
    // from where the scam reached you" (SABICHECK_SPEC.md §3). Return `false`
    // instead to show a small compose sheet with a Send button first.
    override func shouldAutoRedirect() -> Bool {
        return true
    }
}
