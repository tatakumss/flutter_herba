# Firestore Security Rules for PediaHerb

## Complete Security Rules

Copy and paste these rules into your Firebase Console → Firestore Database → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Each user controls their own document
    match /users/{userId} {
      // Allow the user to read/write their own user doc
      // This now includes base64 profile photos in photoUrl field
      allow read, write: if request.auth != null && request.auth.uid == userId;

      // User's scans subcollection
      match /scans/{scanId} {
        // Reads: path-based check is enough
        allow read: if request.auth != null && request.auth.uid == userId;

        // Creates and Updates: ensure the document's userId matches the path user
        allow create, update: if request.auth != null
          && request.auth.uid == userId
          && request.resource.data.userId == userId;
        
        // Deletes: path-based check is sufficient
        allow delete: if request.auth != null && request.auth.uid == userId;
      }

      // User's collections subcollection
      match /collections/{docId} {
        // Reads: path-based check
        allow read: if request.auth != null && request.auth.uid == userId;

        // Creates and Updates: enforce ownership in payload
        allow create, update: if request.auth != null
          && request.auth.uid == userId
          && request.resource.data.userId == userId;
        
        // Deletes: path-based check is sufficient (no payload to verify)
        allow delete: if request.auth != null && request.auth.uid == userId;
      }

      // User's feedback subcollection
      match /feedback/{feedbackId} {
        // Reads: path-based check is enough
        allow read: if request.auth != null && request.auth.uid == userId;

        // Creates and Updates: ensure the document's userId matches the path user
        allow create, update: if request.auth != null
          && request.auth.uid == userId
          && request.resource.data.userId == userId;
        
        // Deletes: path-based check is sufficient
        allow delete: if request.auth != null && request.auth.uid == userId;
      }
    }

    // Plant library (read-only for all authenticated users)
    match /plants/{plantId} {
      allow read: if request.auth != null;
    }
    
    // App configuration (read-only for all authenticated users)
    match /config/{configId} {
      allow read: if request.auth != null;
    }

    // Lock down legacy top-level collections (security enhancement)
    match /collections/{docId} { 
      allow read, write: if false; 
    }
    
    match /scans/{docId} { 
      allow read, write: if false; 
    }
  }
}
```

## Rule Breakdown

### 1. Enhanced User Profiles
```javascript
match /users/{userId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```
- **Purpose**: Users can only access their own profile data
- **Security**: Prevents cross-user data access
- **Base64 Support**: Includes base64 profile photos in photoUrl field
- **Operations**: Full CRUD for own profile

### 2. Secure User Collections
```javascript
match /collections/{docId} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow create, update: if request.auth != null
    && request.auth.uid == userId
    && request.resource.data.userId == userId;
  allow delete: if request.auth != null && request.auth.uid == userId;
}
```
- **Purpose**: Users can manage their own plant collections
- **Enhanced Security**: Separate rules for different operations
- **Read Protection**: Path-based authentication check
- **Create/Update Protection**: Validates userId in document payload
- **Delete Protection**: Path-based check (no payload to validate)
- **Operations**: Secure add, view, update, delete own collections

### 3. Secure User Scans
```javascript
match /scans/{scanId} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow write: if request.auth != null
    && request.auth.uid == userId
    && request.resource.data.userId == userId;
}
```
- **Purpose**: Users can access their scan history
- **Enhanced Security**: Validates userId in document payload
- **Read Protection**: Path-based access control
- **Write Protection**: Prevents userId spoofing
- **Operations**: Secure save and retrieve scan results

### 4. Secure User Feedback
```javascript
match /feedback/{feedbackId} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow write: if request.auth != null
    && request.auth.uid == userId
    && request.resource.data.userId == userId;
}
```
- **Purpose**: Users can submit and view their feedback
- **Enhanced Security**: Double validation for data integrity
- **Read Protection**: User-specific feedback access
- **Write Protection**: Prevents cross-user feedback injection
- **Operations**: Secure submit error reports and suggestions

### 5. Legacy Collection Lockdown
```javascript
match /collections/{docId} { allow read, write: if false; }
match /scans/{docId} { allow read, write: if false; }
```
- **Purpose**: Completely blocks access to legacy top-level collections
- **Security Enhancement**: Prevents accidental data leaks
- **Migration Safety**: Forces use of proper user subcollections
- **Zero Access**: No read or write permissions for anyone

## Setup Instructions

### 1. Apply Rules in Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project: `herba-app-c456a`
3. Navigate to **Firestore Database**
4. Click on **Rules** tab
5. Replace existing rules with the rules above
6. Click **Publish**

### 2. Test Rules
```dart
// Test in your app - this should work
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  // This will succeed - accessing own collections
  await FirebaseFirestore.instance
    .collection('users')
    .doc(user.uid)
    .collection('collections')
    .get();
}
```

### 3. Verify Security
```dart
// This should fail - accessing another user's data
await FirebaseFirestore.instance
  .collection('users')
  .doc('different-user-id')
  .collection('collections')
  .get(); // Will throw permission denied
```

## Database Structure

Your Firestore database will have this structure:

```
/users/{userId}
├── uid: string
├── email: string
├── displayName: string?
├── photoUrl: string?
├── createdAt: timestamp
├── updatedAt: timestamp
├── preferences: map
│
├── /collections/{collectionId}
│   ├── id: string
│   ├── userId: string
│   ├── plantName: string
│   ├── imageUrl: string?
│   ├── imageData: string?
│   ├── addedAt: timestamp
│   ├── notes: string?
│   ├── plantInfo: map
│   └── isFavorite: boolean
│
├── /scans/{scanId}
│   ├── id: string
│   ├── userId: string
│   ├── plantName: string
│   ├── confidence: number
│   ├── isIdentified: boolean
│   ├── scannedAt: timestamp
│   └── imageUrl: string?
│
└── /feedback/{feedbackId}
    ├── id: string
    ├── userId: string
    ├── type: string
    ├── message: string
    ├── timestamp: timestamp
    ├── status: string
    └── scanContext: map
```

## Security Features

### ✅ Enhanced User Isolation
- Each user can only access their own data
- No cross-user data leakage
- Authentication required for all operations
- **Double validation**: Path-based + payload validation

### ✅ Advanced Subcollection Security
- Collections, scans, and feedback are user-specific
- **Enhanced write protection**: Validates userId in document data
- **Prevents spoofing**: Cannot write documents with fake userId
- **Path-based reads**: Efficient authentication checking

### ✅ Legacy Data Protection
- **Complete lockdown** of top-level collections and scans
- **Forces migration** to proper user subcollections
- **Prevents data leaks** from old database structure
- **Zero tolerance** for legacy access patterns

### ✅ Base64 Profile Support
- **Firestore-only** profile photo storage
- **No Firebase Storage** dependency required
- **Optimized** for document size limits
- **Secure** base64 data URL handling

### ✅ Read-Only Resources
- Plant library accessible to all authenticated users
- App configuration shared but protected
- No write access to shared resources

## Security Improvements

### 🔒 Double Validation System
```javascript
// OLD: Simple path-based security
allow write: if request.auth.uid == userId;

// NEW: Enhanced validation
allow write: if request.auth != null
  && request.auth.uid == userId
  && request.resource.data.userId == userId;
```

### 🚫 Legacy Collection Lockdown
```javascript
// Completely blocks legacy top-level collections
match /collections/{docId} { allow read, write: if false; }
match /scans/{docId} { allow read, write: if false; }
```

### 🛡️ Payload Validation
- **Prevents userId spoofing** in document data
- **Ensures data integrity** across all operations
- **Blocks malicious writes** with incorrect user references
- **Maintains consistency** between path and document data

## Troubleshooting

### Common Issues

1. **Permission Denied Error**
   ```
   Error: Missing or insufficient permissions
   ```
   **Solution**: Ensure user is authenticated and accessing own data

2. **Rules Not Applied**
   ```
   Error: Rules appear to be ignored
   ```
   **Solution**: Wait 1-2 minutes after publishing rules

3. **Authentication Required**
   ```
   Error: User must be authenticated
   ```
   **Solution**: Ensure Firebase Auth user is logged in

### Testing Commands

```dart
// Test authentication
final user = FirebaseAuth.instance.currentUser;
print('User authenticated: ${user != null}');

// Test collection access
try {
  final collections = await FirebaseFirestore.instance
    .collection('users')
    .doc(user!.uid)
    .collection('collections')
    .get();
  print('Collections accessible: ${collections.docs.length}');
} catch (e) {
  print('Error accessing collections: $e');
}
```

## Next Steps

1. **Apply the rules** in Firebase Console
2. **Test with your app** to ensure collections work
3. **Monitor usage** in Firebase Console
4. **Add more rules** as you expand features

These rules provide secure, user-isolated access to all PediaHerb features while maintaining proper authentication requirements.
