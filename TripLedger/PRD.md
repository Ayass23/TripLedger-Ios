# Trip Ledger — PRD (iOS App / Vibe Coding Ready)

## Product Vision

Trip Ledger adalah iOS app untuk mengatur keuangan perjalanan grup: catat pengeluaran, split bill, track hutang, settlement, dan laporan dalam satu pengalaman yang simple dan modern.

## Core Users

* Friend group traveling
* Family trip
* Community trip
* Backpacker group

## Roles

* User
* Owner
* Admin

## MVP Features

### Auth

Sign up, login, forgot password, reset password, suspend handling, logout.

### Profile

Edit profile, upload avatar, bank account info.

### Friends

Search user, add friend, accept/reject request, friend list.

### Trips

Create trip, invite member, join/reject invite, active trip, history, finish trip, delete trip.

### Members

View members, kick member, transfer ownership, leave trip.

### Expenses

Manual add expense, OCR receipt scan, edit scan result, categories, split equally, split by item, edit/delete expense, expense history.

### Debt & Settlement

Auto balance calculation, min cash flow algorithm, payment proof upload, verify/reject payment, settlement history.

### Reports & Notifications

Trip summary, category chart, export PDF, inbox notifications, unread states.

### Admin

User management, suspend user, delete user, trip moderation, app stats.

---

## iOS Tech Stack

* SwiftUI
* MVVM
* Firebase Auth
* Firestore
* Firebase Storage
* Cloud Functions
* Push Notification (FCM + APNs)
* Swift Charts
* PDFKit
* Vision OCR

## Suggested Screens

1. Welcome
2. Login / Register
3. Home Trips
4. Create Trip
5. Trip Detail
6. Add Expense
7. Receipt Scan Review
8. Settlement
9. Notifications
10. Profile

## UX Direction

* Clean finance UI
* Fast actions
* Floating CTA Add Expense
* Dark mode
* Smooth animation
* Clear debt badges

## V1 Build Order

1. Auth
2. Trips
3. Manual Expense
4. Split Equally
5. Debt Simplification
6. Settlement Proof
7. Notifications
8. Reports

## V2

* Better OCR
* Multi currency
* Offline mode
* AI spending insights
* Shared itinerary

## Success Metrics

* Trips created
* Expenses logged
* Debt settled rate
* Retention
* MAU

