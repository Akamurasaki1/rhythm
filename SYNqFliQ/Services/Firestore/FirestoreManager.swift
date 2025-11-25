import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine
import UIKit

/// FirestoreManager: user-scoped read/write and upload queue for CloudPlayRecord.
public final class FirestoreManager: ObservableObject {
    public static let shared = FirestoreManager()
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    @Published public private(set) var profile: UserProfile? = nil
    @Published public private(set) var favorites: [String] = []
    @Published public private(set) var currency: Int = 0
    @Published public private(set) var showRank: Bool = true

    // upload queue persisted to UserDefaults (stores CloudPlayRecord)
    private var uploadQueue: [CloudPlayRecord] = []
    private var isUploadingQueue = false

    private init() {
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        db.settings = settings

        // listen to auth changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.detachAll()
            if let u = user {
                self?.attachListeners(uid: u.uid)
            } else {
                self?.profile = nil; self?.favorites = []; self?.currency = 0; self?.showRank = true
            }
        }

    }

    private func attachListeners(uid: String) {
        // profile doc
        let pRef = db.collection("users").document(uid)
        let reg1 = pRef.addSnapshotListener { [weak self] snap, err in
            if let data = snap?.data() {
                let displayName = data["displayName"] as? String
                // now supporting iconBase64 field
                let iconURL = data["iconURL"] as? String
                let iconBase64 = data["iconBase64"] as? String
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
                var up = UserProfile(uid: uid, displayName: displayName, iconURL: iconURL, createdAt: createdAt)
                // store base64 in iconURL temporarily? better to extend UserProfile if desired.
                // For now we stash base64 into iconURL if iconURL is nil to keep compatibility.
                if let b64 = iconBase64, iconURL == nil {
                    up.iconURL = "data:image/jpeg;base64,\(b64)"
                }
                self?.profile = up
            } else {
                self?.profile = nil
            }
        }
        listeners.append(reg1)

        // favorites (meta collection / favorites doc)
        let favRef = db.collection("users").document(uid).collection("meta").document("favorites")
        let reg2 = favRef.addSnapshotListener { [weak self] snap, err in
            if let data = snap?.data(), let arr = data["favorites"] as? [String] {
                self?.favorites = arr
            } else {
                self?.favorites = []
            }
        }
        listeners.append(reg2)

        // currency
        let curRef = db.collection("users").document(uid).collection("meta").document("currency")
        let reg3 = curRef.addSnapshotListener { [weak self] snap, err in
            if let data = snap?.data(), let amt = data["amount"] as? Int {
                self?.currency = amt
            } else {
                self?.currency = 0
            }
        }
        listeners.append(reg3)

        // settings (showRank etc.)
        let setRef = db.collection("users").document(uid).collection("meta").document("settings")
        let reg4 = setRef.addSnapshotListener { [weak self] snap, err in
            if let data = snap?.data(), let sr = data["showRank"] as? Bool {
                self?.showRank = sr
            } else {
                self?.showRank = true
            }
        }
        listeners.append(reg4)
    }

    private func detachAll() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

    // MARK: Upload queue persistence (CloudPlayRecord)
   


    // MARK: - Image handling without Storage
        /// Resize and compress UIImage, then save as base64 string to users/{uid}.iconBase64
        /// Ensures the stored data remains under ~900KB (Firestore doc limit safety margin)
        public func uploadProfileImageAsBase64(_ image: UIImage, maxDimension: CGFloat = 256, jpegQuality: CGFloat = 0.6, completion: @escaping (Result<Void, Error>) -> Void) {
            guard let uid = Auth.auth().currentUser?.uid else {
                completion(.failure(NSError(domain: "FirestoreManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])))
                return
            }

            // resize
            let resized = image.resized(toMaxDimension: maxDimension)
            // compress
            guard var data = resized.jpegData(compressionQuality: jpegQuality) else {
                completion(.failure(NSError(domain: "FirestoreManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to encode image"])))
                return
            }

            // if too large, iteratively reduce quality and/or dimension
            var currentQuality = jpegQuality
            var currentMaxDim = maxDimension
            let maxAllowedBytes = 900 * 1024 // 900 KB safety margin
            while data.count > maxAllowedBytes && currentQuality > 0.15 {
                currentQuality -= 0.1
                if let d = resized.jpegData(compressionQuality: currentQuality) {
                    data = d
                } else {
                    break
                }
            }
            if data.count > maxAllowedBytes {
                // try further downscale
                while data.count > maxAllowedBytes && currentMaxDim > 64 {
                    currentMaxDim = max(64, currentMaxDim * 0.8)
                    let smaller = image.resized(toMaxDimension: currentMaxDim)
                    if let d = smaller.jpegData(compressionQuality: max(0.3, currentQuality)) {
                        data = d
                    } else { break }
                }
            }

            if data.count > maxAllowedBytes {
                completion(.failure(NSError(domain: "FirestoreManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Image too large after compression (\(data.count) bytes)"])))
                return
            }

            let b64 = data.base64EncodedString(options: [])
            let pRef = db.collection("users").document(uid)
            pRef.setData(["iconBase64": b64, "iconUpdatedAt": FieldValue.serverTimestamp()], merge: true) { err in
                if let e = err { completion(.failure(e)); return }
                completion(.success(()))
            }
        }

        // Save displayName (and optionally iconBase64 already saved separately)
        public func saveProfileDisplayName(displayName: String?, completion: ((Error?) -> Void)? = nil) {
            guard let uid = Auth.auth().currentUser?.uid else {
                completion?(NSError(domain: "FirestoreManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "not signed in"]))
                return
            }
            let pRef = db.collection("users").document(uid)
            var data: [String: Any] = [:]
            if let name = displayName { data["displayName"] = name }
            data["updatedAt"] = FieldValue.serverTimestamp()
            pRef.setData(data, merge: true, completion: completion)
        }

        // settings save
        public func setShowRank(_ show: Bool, completion: ((Error?) -> Void)? = nil) {
            guard let uid = Auth.auth().currentUser?.uid else {
                completion?(NSError(domain: "FirestoreManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "not signed in"]))
                return
            }
            let setRef = db.collection("users").document(uid).collection("meta").document("settings")
            setRef.setData(["showRank": show], merge: true, completion: completion)
        }
    }

    // MARK: - UIImage helper: resize
    fileprivate extension UIImage {
        /// Resize so that max(width, height) <= maxDimension while keeping aspect ratio
        func resized(toMaxDimension maxDimension: CGFloat) -> UIImage {
            let maxSide = max(size.width, size.height)
            guard maxSide > maxDimension else { return self }
            let scale = maxDimension / maxSide
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
            draw(in: CGRect(origin: .zero, size: newSize))
            let img = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return img ?? self
        }
    }
