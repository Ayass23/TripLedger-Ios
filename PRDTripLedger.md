# TripLedger - Product Requirements Document (iOS)

## Executive Summary

**Product Name:** TripLedger
**Platform:** iOS (iPhone & iPad)
**Version:** 1.0
**Target OS:** iOS 16.0+
**Category:** Finance & Travel
**Purpose:** Comprehensive group travel expense management with intelligent debt settlement

TripLedger is a native iOS application designed to solve the complexity of managing shared expenses during group travel. It combines receipt scanning via OCR, intelligent debt simplification algorithms, and seamless payment verification to make group financial management effortless.

---

## Product Vision

Create the most intuitive and delightful iOS experience for managing group travel finances, where tracking expenses, splitting bills, and settling debts feels natural and requires minimal effort.

---

## Target Users

### Primary Users
- **Friend Groups (Ages 20-35):** Weekend trips, road trips, group activities
- **Families:** Multi-generational family vacations
- **Travel Communities:** Backpacker groups, organized tour groups
- **Corporate Teams:** Team retreats and business travel groups

### User Personas

**Persona 1: Maya - The Trip Organizer**
- Age: 28, Marketing Manager
- Pain: Manually tracking who owes what on Google Sheets
- Goal: Automated tracking and fair expense distribution
- Technical: Comfortable with iOS apps, uses Apple Pay

**Persona 2: David - The Frequent Traveler**
- Age: 32, Travel Blogger
- Pain: Managing expenses across multiple concurrent trips
- Goal: Quick expense logging with minimal friction
- Technical: Power user, expects smooth UX

**Persona 3: Linda - The Family Coordinator**
- Age: 45, Teacher
- Pain: Keeping track of family vacation expenses
- Goal: Simple interface, clear visual reports
- Technical: Moderate tech literacy

---

## User Roles & Permissions

| Role | Description | Permissions |
|------|-------------|-------------|
| **User** | Standard member of a trip | View trip, add own expenses, view debts, make payments |
| **Owner** | Trip creator with management rights | All User permissions + edit all expenses, manage members, transfer ownership, delete trip |
| **Admin** | System administrator | User management, suspend accounts, trip moderation, view statistics |

---

## iOS Design System

### Color Palette

#### Primary Colors
```swift
// Brand Identity
Primary:         #4A90E2  // Vibrant Blue - Main actions, CTAs
PrimaryDark:     #2E5C8A  // Deep Blue - Pressed states
PrimaryLight:    #7AB8FF  // Light Blue - Backgrounds, highlights

// Semantic Colors
Success:         #34C759  // iOS Green - Payment verified, success states
Warning:         #FF9500  // iOS Orange - Pending actions, warnings
Error:           #FF3B30  // iOS Red - Errors, delete actions
Info:            #5AC8FA  // iOS Cyan - Information, tips

// Financial Colors
Positive:        #34C759  // Green - Money owed to you (credit)
Negative:        #FF3B30  // Red - Money you owe (debt)
Settled:         #8E8E93  // Gray - Settled/balanced amounts
Neutral:         #007AFF  // iOS Blue - Even split, neutral state
```

#### Neutral Colors
```swift
// Backgrounds (Light Mode)
Background:      #FFFFFF  // Primary background
SecondaryBG:     #F2F2F7  // Secondary background, grouped lists
TertiaryBG:      #E5E5EA  // Tertiary background, disabled states

// Backgrounds (Dark Mode)
Background:      #000000  // Primary background
SecondaryBG:     #1C1C1E  // Secondary background
TertiaryBG:      #2C2C2E  // Tertiary background

// Text Colors (Adaptive)
TextPrimary:     #000000 (light) / #FFFFFF (dark)
TextSecondary:   #3C3C43 (light) / #EBEBF5 (dark) @ 60% opacity
TextTertiary:    #3C3C43 (light) / #EBEBF5 (dark) @ 30% opacity
TextDisabled:    #3C3C43 (light) / #EBEBF5 (dark) @ 20% opacity

// Borders & Dividers
Border:          #C6C6C8 (light) / #38383A (dark)
Divider:         #E5E5EA (light) / #48484A (dark)
```

#### Category Colors (Expense Types)
```swift
Food:            #FF6B6B  // Coral Red
Transportation:  #4ECDC4  // Turquoise
Accommodation:   #95E1D3  // Mint Green
Activities:      #FFD93D  // Yellow
Shopping:        #A8E6CF  // Pastel Green
Others:          #B4B4B8  // Gray
```

### Typography

```swift
// iOS Native Fonts (San Francisco)
LargeTitle:      34pt, Bold         // Screen titles
Title1:          28pt, Bold         // Section headers
Title2:          22pt, Bold         // Card titles
Title3:          20pt, Semibold     // List headers
Headline:        17pt, Semibold     // Emphasis text
Body:            17pt, Regular      // Primary text
Callout:         16pt, Regular      // Secondary text
Subheadline:     15pt, Regular      // Supporting text
Footnote:        13pt, Regular      // Captions, helper text
Caption1:        12pt, Regular      // Timestamps, metadata
Caption2:        11pt, Regular      // Fine print

// Numeric Display (Monospaced)
CurrencyLarge:   34pt, Bold, Monospaced      // Main balance display
CurrencyMedium:  22pt, Semibold, Monospaced  // Expense amounts
CurrencySmall:   17pt, Regular, Monospaced   // List amounts
```

### Spacing System

```swift
// Consistent 8-point grid
XXS:  4pt   // Tight spacing, badges
XS:   8pt   // Component padding
S:    12pt  // Compact spacing
M:    16pt  // Standard spacing (default)
L:    24pt  // Section spacing
XL:   32pt  // Major sections
XXL:  48pt  // Screen margins (top/bottom)
```

### Corner Radius

```swift
Small:   8pt   // Buttons, tags, badges
Medium:  12pt  // Cards, inputs
Large:   16pt  // Modals, sheets
XLarge:  24pt  // Hero cards
Pill:    9999  // Fully rounded (capsule)
```

### Shadows & Elevation

```swift
// Light Mode
Shadow1: 0 1px 3px rgba(0,0,0,0.12)   // Subtle elevation
Shadow2: 0 2px 8px rgba(0,0,0,0.15)   // Cards
Shadow3: 0 4px 16px rgba(0,0,0,0.18)  // Modals, floating elements

// Dark Mode
Shadow1: 0 1px 3px rgba(0,0,0,0.3)
Shadow2: 0 2px 8px rgba(0,0,0,0.4)
Shadow3: 0 4px 16px rgba(0,0,0,0.5)
```

### iOS-Specific Components

- **Navigation Bar:** Large Title style (scrollable collapse)
- **Tab Bar:** Standard iOS tab bar with SF Symbols
- **Lists:** Inset Grouped style (rounded corners)
- **Sheets:** Bottom sheet modals with drag indicator
- **Action Sheets:** Native iOS action sheet style
- **Alerts:** Native iOS alert dialogs
- **SF Symbols:** Use iOS system icons for consistency

---

## Feature Breakdown (110 Functionalities)

### I. AUTHENTICATION & ACCESS (15 Features)

#### 1. Landing Page
**Functionality:** Display app information to unauthenticated users
**Screen:** WelcomeView
**Components:**
- Hero image/animation
- App logo and tagline
- Key value propositions (3-4 bullet points)
- "Get Started" primary button
- "Sign In" secondary button

**iOS Design:**
- Full screen with safe area consideration
- Scroll view for smaller devices
- SF Symbols for feature icons
- Smooth parallax animation on scroll

#### 2. Sign Up / Registration
**Functionality:** New user registration
**Input Fields:**
- Full Name (Text Field)
- Email (Email Field with keyboard type)
- Password (Secure Field, toggle visibility)
- Confirm Password (Secure Field)

**Validation Rules:**
- Email format validation (regex)
- Password minimum 8 characters
- Password confirmation match
- Real-time validation feedback

**iOS Design:**
- Sheet presentation style
- Floating labels
- Inline validation with icons (checkmark/x)
- Native keyboard with "Next" and "Done" actions
- Auto-fill support (Sign in with Apple optional V2)

#### 3. Email Already Registered Error
**Functionality:** Database validation for duplicate emails
**Trigger:** On sign-up submission
**Response:** Alert with "Email already registered. Please sign in or use a different email."
**Action:** Dismiss alert and return to form with email field focused

#### 4. Invalid Format Error
**Functionality:** Client-side validation
**Email:** Standard email regex
**Password:** Min 8 chars, requires letter + number (optional special char)
**Display:** Inline error text below field in Error color

#### 5. Registration Success Alert
**Functionality:** Confirmation feedback
**Type:** Toast notification (top banner, 3sec auto-dismiss)
**Message:** "Account created successfully! Welcome to TripLedger"
**Action:** Auto-navigate to onboarding or home

#### 6. Login
**Functionality:** User authentication
**Screen:** LoginView
**Input Fields:**
- Email (Email Field)
- Password (Secure Field)

**Components:**
- Remember Me toggle (optional)
- Forgot Password link
- Sign In button (Primary)
- Divider with "OR"
- "Don't have an account? Sign Up" link

**iOS Design:**
- Compact form centered on screen
- Auto-fill credentials support
- Face ID / Touch ID authentication (V2)
- Keyboard avoidance behavior

#### 7. Invalid Credentials Error
**Functionality:** Authentication failure handling
**Trigger:** Wrong email or password
**Response:** Alert with "Invalid email or password. Please try again."
**Security:** Generic message (don't specify which is wrong)

#### 8. Suspended Account Alert
**Functionality:** Prevent suspended users from accessing app
**Trigger:** Login attempt with suspended account
**Response:** Alert with "Your account has been suspended. Contact support."
**Action:** Lock user out of dashboard, return to login

#### 9. Role-Based Menu Activation
**Functionality:** Show/hide features based on user role
**Implementation:**
- User: Standard menu (Trips, Expenses, Profile, Notifications)
- Owner: + Trip Management, Member Management
- Admin: + Admin Dashboard, User Management

**iOS Design:**
- Tab Bar for User/Owner
- Settings gear icon reveals Admin Dashboard for Admin role
- Context-based toolbar buttons

#### 10. Request Reset Password
**Functionality:** Initiate password reset flow
**Screen:** ForgotPasswordView
**Input:** Email address
**Action:** Send reset link to email
**Feedback:** "Password reset link sent to [email]. Check your inbox."

#### 11. Send Reset Email
**Functionality:** Automated email delivery
**Service:** Firebase Auth / Backend email service
**Email Content:**
- Subject: "Reset Your TripLedger Password"
- Body: Reset link (expires in 1 hour)
- Branding: Logo and brand colors

#### 12. Reset Password via Link
**Functionality:** Deep link handling
**Flow:**
1. User clicks email link
2. App opens to ResetPasswordView
3. User enters new password
4. Password updated
5. Success confirmation
6. Redirect to Login

**iOS Design:**
- Universal Links for seamless deep linking
- Native sheet presentation

#### 13. Change Password from Settings
**Functionality:** In-app password change
**Screen:** SettingsView → ChangePasswordView
**Input Fields:**
- Current Password (Secure Field)
- New Password (Secure Field)
- Confirm New Password (Secure Field)

**Validation:**
- Verify current password against database
- New password meets requirements
- Confirmation matches

#### 14. Incorrect Old Password Error
**Functionality:** Validation for current password
**Trigger:** Wrong current password entered
**Response:** Inline error "Current password is incorrect"

#### 15. Logout
**Functionality:** End user session
**Action:** Clear auth token, reset navigation stack, return to Welcome
**Confirmation:** Optional alert for unsaved changes
**iOS Design:** Settings list item with logout icon (SF Symbol: arrow.right.square)

---

### II. PROFILE MANAGEMENT (7 Features)

#### 16. View Own Profile
**Functionality:** Display user profile information
**Screen:** ProfileView
**Data Display:**
- Profile photo (circular, 120pt diameter)
- Full Name (Title1)
- Username (Callout, secondary color)
- Bio (Body, 3 lines max)
- Email (Footnote)
- Member Since (Footnote)
- Bank Account Info (if added)

**iOS Design:**
- Scroll view
- Large circular avatar at top
- Inset grouped list for information
- Edit button in navigation bar

#### 17. Edit Profile
**Functionality:** Update user information
**Screen:** EditProfileView
**Editable Fields:**
- Full Name (Text Field)
- Username (Text Field, unique validation)
- Bio (Text Editor, 150 char limit)

**iOS Design:**
- Sheet presentation
- Save/Cancel buttons in navigation
- Character count for bio
- Real-time save state

#### 18. Upload / Change Profile Photo
**Functionality:** Profile picture management
**Options:**
- Take Photo (Camera)
- Choose from Library (Photo Picker)
- Default Avatar

**Implementation:**
- PHPickerViewController for photo selection
- Image compression before upload
- Circular crop with zoom/pan
- Upload to Firebase Storage

**iOS Design:**
- Action Sheet for source selection
- Native photo picker
- Crop overlay with grid

#### 19. Photo Size Error
**Functionality:** File size validation
**Rule:** Max 2MB
**Trigger:** On photo selection
**Response:** Alert "Photo size exceeds 2MB. Please choose a smaller image."
**Action:** Return to picker

#### 20. Delete Profile Photo
**Functionality:** Remove custom avatar
**Action:** Revert to default avatar (initials on colored background)
**Confirmation:** Action Sheet "Remove Profile Photo?"
**Options:** Remove / Cancel

#### 21. Incomplete Profile Error
**Functionality:** Profile/bank account validation
**Trigger:** Attempting actions requiring complete profile
**Response:** Alert "Please complete your profile and bank account information first."
**Action:** Navigate to ProfileEditView

#### 22. Profile Update Success
**Functionality:** Update confirmation
**Type:** Toast notification
**Message:** "Profile updated successfully"
**Duration:** 2 seconds

---

### III. FRIEND MANAGEMENT (11 Features)

#### 23. Search User
**Functionality:** Find users by username or email
**Screen:** FriendsView → SearchBar
**Implementation:**
- Search bar in navigation
- Real-time search (debounced 300ms)
- Search by username or email
- Display results in list

**iOS Design:**
- Native UISearchController
- Search icon and placeholder "Search by username or email"
- Clear button
- Recent searches (stored locally)

#### 24. User Not Found Error
**Functionality:** Empty search results
**Display:** Empty state view
**Content:** SF Symbol (magnifyingglass) + "No users found"
**Suggestion:** "Check spelling or try a different search"

#### 25. Add Friend
**Functionality:** Send friend request
**Trigger:** Tap user in search results
**Action:** Send friend request to selected user
**Button:** "Add Friend" (Primary button)
**State Change:** "Request Sent" (disabled, gray)

#### 26. Already Friends Alert
**Functionality:** Prevent duplicate friend requests
**Trigger:** Attempting to add existing friend
**Response:** Toast "You're already friends with [username]"

#### 27. Friend List
**Functionality:** Display all friends
**Screen:** FriendsView → Friends Tab
**List Display:**
- Profile photo (40pt circle)
- Name (Headline)
- Username (Subheadline, secondary)
- Chevron right for detail view

**iOS Design:**
- Inset grouped list
- Swipe actions: Remove Friend
- Alphabetical sections with index
- Pull to refresh

#### 28. Remove Friend
**Functionality:** Delete friendship
**Trigger:** Swipe left on friend in list → Delete action
**Alternative:** Friend detail view → Remove Friend button

#### 29. Remove Friend Confirmation
**Functionality:** Prevent accidental removal
**Type:** Action Sheet
**Title:** "Remove [Name] from friends?"
**Message:** "You can send a new friend request later."
**Actions:**
- Remove (Destructive) - Red text
- Cancel

#### 30. Pending Friend Requests
**Functionality:** View incoming friend requests
**Screen:** FriendsView → Requests Tab
**Badge:** Unread count on tab icon
**List Display:**
- Profile photo
- Name and username
- Time sent (relative time)
- Accept / Decline buttons

**iOS Design:**
- Horizontal button stack
- Accept (Primary) / Decline (Secondary)
- Swipe actions as alternative

#### 31. Accept Friend Request
**Functionality:** Approve friendship
**Action:** Create bidirectional friend relationship
**Feedback:** Toast "You're now friends with [Name]"
**State:** Move from Requests to Friends list

#### 32. Decline Friend Request
**Functionality:** Reject friendship
**Action:** Delete request record
**Feedback:** Toast "Friend request declined"
**State:** Remove from list with animation

#### 33. Friendship Status Update Success
**Functionality:** Confirmation for accept/decline
**Type:** Toast notification
**Duration:** 2 seconds
**Animation:** Smooth removal from list

---

### IV. TRIP MANAGEMENT (14 Features)

#### 34. Create New Trip
**Functionality:** Initialize new trip
**Screen:** HomeView → Floating "+" button → CreateTripView
**Input Fields:**
- Trip Name (Text Field, required)
- Destination (Text Field, required)
- Start Date (Date Picker)
- End Date (Date Picker, must be >= start date)
- Description (Text Editor, optional)
- Cover Photo (Photo Picker, optional)

**Business Logic:**
- Creator automatically becomes Owner
- Trip status = Active
- Initial member count = 1

**iOS Design:**
- Sheet presentation (full height)
- Form with sections
- Native date pickers (inline style)
- Create button in navigation (disabled until valid)

#### 35. Empty Required Fields Error
**Functionality:** Form validation
**Trigger:** Attempting to create trip with empty name/destination
**Response:** Shake animation on empty fields + inline error text
**Message:** "This field is required"

#### 36. Edit Trip
**Functionality:** Update trip details
**Access:** Owner only
**Screen:** TripDetailView → Edit button → EditTripView
**Editable Fields:**
- Trip Name
- Destination
- Start Date
- End Date
- Description
- Cover Photo

**iOS Design:**
- Same form layout as Create
- Pre-filled with existing data
- Save/Cancel buttons

#### 37. Active Trips List
**Functionality:** Display all ongoing trips
**Screen:** HomeView → Active Tab
**Card Display:**
- Cover photo (background)
- Trip name (Title2, white text with shadow)
- Destination + dates (Callout)
- Member count icon + number
- Balance indicator:
  - Green badge: "You're owed Rp[amount]"
  - Red badge: "You owe Rp[amount]"
  - Gray: "Settled"

**iOS Design:**
- Vertical scroll
- Cards with 16pt spacing
- Gradient overlay on cover photo for text readability
- Tap to open TripDetailView

#### 38. Trip History (Finished)
**Functionality:** Archive of completed trips
**Screen:** HomeView → History Tab
**Display:** Same card layout as Active, with "Completed" tag
**Filter:** Only trips with status = Finished

#### 39. Search Trips
**Functionality:** Filter trips by name or destination
**Implementation:**
- Search bar in navigation (on Home)
- Search both active and history
- Highlight matching text

#### 40. Mark Trip as Finished
**Functionality:** Archive trip
**Access:** Owner only
**Trigger:** TripDetailView → More menu → Finish Trip
**Pre-condition Check:** All debts must be settled

#### 41. Outstanding Debt Error
**Functionality:** Prevent finishing with unsettled debts
**Trigger:** Attempting to finish trip with pending balances
**Response:** Alert "Cannot finish trip. There are outstanding debts."
**Action:** Show DebtView with unsettled amounts highlighted

#### 42. Delete Trip
**Functionality:** Permanently remove trip
**Access:** Owner only
**Trigger:** TripDetailView → More menu → Delete Trip

#### 43. Delete Trip Confirmation
**Functionality:** Prevent accidental deletion
**Type:** Alert (destructive style)
**Title:** "Delete Trip?"
**Message:** "This will permanently delete all expenses, photos, and history. This cannot be undone."
**Actions:**
- Delete (Destructive, red)
- Cancel

#### 44. Non-Owner Delete Error
**Functionality:** Permission enforcement
**Trigger:** Non-owner attempts to delete trip
**Response:** Alert "Only the trip owner can delete this trip."
**Note:** Delete button should not be visible to non-owners

#### 45. Invite Members
**Functionality:** Add friends to trip
**Screen:** TripDetailView → Members → Invite button → InviteMembersView
**Source:** Friend list only
**Display:**
- Friend list with checkboxes
- Filter out already-invited friends
- Multi-select enabled
- Send Invites button (shows count)

**Business Logic:**
- Create invitation records
- Send push notifications to invitees
- Status = Pending

#### 46. Accept Trip Invitation
**Functionality:** Join trip
**Trigger:** NotificationView → Invitation card → Accept
**Action:**
- Add user to trip members
- Update invitation status = Accepted
- Send notification to trip owner

**iOS Design:**
- Inline buttons in notification card
- Accept (Primary) / Decline (Secondary)

#### 47. Decline Trip Invitation
**Functionality:** Reject trip membership
**Action:** Update invitation status = Declined
**Feedback:** Toast "Invitation declined"
**Notification:** Notify trip owner

---

### V. TRIP MEMBERSHIP (8 Features)

#### 48. Member List
**Functionality:** Display all trip participants
**Screen:** TripDetailView → Members Tab
**List Display:**
- Profile photo
- Name
- Balance status:
  - Positive (green): "+Rp[amount]"
  - Negative (red): "-Rp[amount]"
  - Zero (gray): "Settled"
- Owner badge (crown icon)

**iOS Design:**
- Inset grouped list
- Tap for member detail view
- Sort: Owner first, then alphabetical

#### 49. Search Members
**Functionality:** Filter member list
**Implementation:** Search bar filters by name
**Real-time:** Filter as user types

#### 50. Kick Member
**Functionality:** Remove member from trip
**Access:** Owner only
**Trigger:** MemberDetailView → Remove button
**Pre-condition:** Member must have zero balance

#### 51. Kick Confirmation
**Functionality:** Confirm member removal
**Type:** Action Sheet
**Title:** "Remove [Name] from trip?"
**Message:** "They will lose access to all trip data."
**Actions:**
- Remove (Destructive)
- Cancel

#### 52. Cannot Kick with Debt Error
**Functionality:** Enforce debt settlement before removal
**Trigger:** Attempting to kick member with non-zero balance
**Response:** Alert "Cannot remove member with outstanding balance. Settle debts first."
**Display:** Show member's current balance in alert

#### 53. Transfer Ownership
**Functionality:** Assign owner role to another member
**Access:** Current owner only
**Screen:** TripDetailView → Settings → Transfer Ownership
**Member Selection:** List of all members (exclude self)
**Confirmation Required**

**Type:** Alert
**Title:** "Transfer ownership to [Name]?"
**Message:** "You will become a regular member. This cannot be undone."
**Actions:**
- Transfer (Destructive)
- Cancel

#### 54. Ownership Transfer Success
**Functionality:** Confirm role change
**Action:**
- Update old owner role = User
- Update new owner role = Owner
- Send push notification to new owner

**Feedback:** Toast "Ownership transferred to [Name]"

#### 55. Leave Trip
**Functionality:** Exit trip membership
**Access:** All users except owner with members
**Rule:** Owner must transfer ownership first if trip has other members
**Confirmation Required**

**iOS Design:**
- Settings → Leave Trip (destructive button)
- Action Sheet confirmation
- If owner with members: Show error "Transfer ownership first"

---

### VI. EXPENSE MANAGEMENT (22 Features)

#### 56. Add Manual Expense
**Functionality:** Manual expense entry
**Screen:** TripDetailView → Floating "+" → AddExpenseView
**Input Fields:**
- Expense Title (Text Field, required)
- Amount (Number Field, required, currency)
- Category (Picker)
- Date (Date Picker, default = today)
- Notes (Text Editor, optional)
- Paid By (Picker from member list, default = current user)
- Attach Photo (optional)

**iOS Design:**
- Form with sections
- Currency input with numeric keyboard
- Category picker with icons
- Save button (navigation bar)

#### 57. Scan Receipt
**Functionality:** Receipt capture via camera
**Trigger:** AddExpenseView → "Scan Receipt" button
**Options:**
- Take Photo (Camera)
- Choose from Library

**iOS Design:**
- Action Sheet for source selection
- Full-screen camera view
- Capture button
- Flash/grid toggles

#### 58. Upload Receipt Photo
**Functionality:** Attach receipt image to expense
**Source:** Camera or Photo Library
**Format:** JPG/PNG
**Size Limit:** 5MB
**Storage:** Firebase Storage

#### 59. OCR AI Extraction
**Functionality:** Automatically extract receipt data
**Technology:** Vision Framework (iOS native) or Cloud Vision API
**Extracted Data:**
- Merchant name (for title)
- Total amount
- Date
- Line items (if possible)

**Processing:**
- Show loading indicator
- Process in background
- 5-10 second timeout

#### 60. Blurry Image Error
**Functionality:** Quality validation
**Trigger:** OCR confidence < 60%
**Response:** Alert "Image quality is too low. Please retake photo or enter manually."
**Options:**
- Retake
- Enter Manually

#### 61. Preview Scan Results
**Functionality:** Review and confirm OCR output
**Screen:** ScanPreviewView
**Display:**
- Receipt thumbnail
- Extracted data in form fields (editable)
- Confidence indicators (checkmark/warning)
- Item list (if extracted)

**iOS Design:**
- Split view: image top, data bottom
- Editable fields
- Confirm/Retake buttons

#### 62. Edit Scan Results
**Functionality:** Correct OCR errors
**Implementation:** All extracted fields are editable
**Validation:** Same as manual entry

#### 63. Add Item Manually
**Functionality:** Add expense line items
**Screen:** AddExpenseView → Items section → Add Item
**Item Fields:**
- Item name (Text Field)
- Quantity (Number Field, default 1)
- Price per unit (Number Field)
- Total (auto-calculated)

**iOS Design:**
- List of items
- Add button
- Swipe to delete

#### 64. Delete Item Before Save
**Functionality:** Remove item from list
**Trigger:** Swipe left on item → Delete
**Action:** Remove from local array (pre-save)

#### 65. Select Expense Category
**Functionality:** Categorize expense for reporting
**Options:**
- Food & Dining 🍴
- Transportation 🚗
- Accommodation 🏨
- Activities 🎯
- Shopping 🛍️
- Others 📦

**iOS Design:**
- Picker with icons and category colors
- Default = Others

#### 66. Split Equally
**Functionality:** Divide expense evenly among selected members
**Screen:** AddExpenseView → Split section → "Split Equally"
**Member Selection:** Multi-select member list
**Calculation:** Total Amount / Number of Selected Members
**Display:** Show each person's share

**iOS Design:**
- Toggle "Split Equally" switch
- Member selection sheet
- Live calculation preview

#### 67. Split by Item
**Functionality:** Assign specific items to specific members
**Screen:** AddExpenseView → Split section → "Split by Item"
**Implementation:**
- For each item, select which members share it
- If item shared: divide equally among selected
- Show running total per person

**iOS Design:**
- Item list with expandable rows
- Checkboxes for member selection per item
- Summary view showing each member's total

#### 68. Split Total Mismatch Error
**Functionality:** Validate split allocation
**Trigger:** Total of splits ≠ expense amount
**Response:** Alert "Split amounts don't match total expense. Please adjust."
**Display:** Show expected vs. actual total

#### 69. Save Expense
**Functionality:** Commit expense to database
**Validation:**
- Required fields filled
- Split totals match
- Valid date

**Action:**
- Save to Firestore
- Upload receipt photo to Storage
- Calculate balances
- Send notifications to trip members
- Return to expense list

#### 70. Expense List
**Functionality:** Display all trip expenses
**Screen:** TripDetailView → Expenses Tab
**List Display:**
- Date section headers (Today, Yesterday, Mar 15, etc.)
- Expense card:
  - Category icon + color
  - Title (Headline)
  - Paid by [Name] (Footnote)
  - Amount (CurrencyMedium)
  - Receipt thumbnail (if available)
  - Your share: Rp[amount] (if applicable)

**iOS Design:**
- Inset grouped list
- Chronological order (newest first)
- Swipe actions: Edit (Owner), Delete
- Pull to refresh

#### 71. Expense Detail
**Functionality:** View full expense information
**Screen:** ExpenseDetailView
**Display Sections:**
- Receipt photo (full width, zoomable)
- Amount (large, center)
- Paid by [Name]
- Category
- Date
- Notes
- Split Details:
  - List of members with their share
  - Split method indicator

**iOS Design:**
- Scroll view
- Hero image at top
- Inset grouped list for details
- Edit button (if permitted)

#### 72. View Receipt Photo
**Functionality:** Full-screen photo viewer
**Trigger:** Tap receipt thumbnail
**Features:**
- Pinch to zoom
- Pan gesture
- Dismiss swipe down

**iOS Design:**
- Full screen modal
- Black background
- Close button (X)

#### 73. Search Expenses
**Functionality:** Filter expense list
**Screen:** Expenses Tab → Search bar
**Search Fields:** Title, category, paid by
**Real-time:** Filter as user types

#### 74. Filter by Category
**Functionality:** Show expenses for specific category
**Screen:** Expenses Tab → Filter button → CategoryFilterView
**Options:**
- All (default)
- Category list with icons
- Multi-select enabled

**iOS Design:**
- Sheet presentation
- Checkboxes for categories
- Apply button

#### 75. Edit Expense
**Functionality:** Modify existing expense
**Access:**
- User: Own expenses only
- Owner: All expenses

**Screen:** ExpenseDetailView → Edit → EditExpenseView
**Implementation:** Same form as Add Expense, pre-filled
**Validation:** Same rules as creation
**Note:** Editing recalculates all balances

#### 76. Delete Expense
**Functionality:** Remove expense
**Access:** Same as Edit
**Trigger:** ExpenseDetailView → More menu → Delete

#### 77. Delete Expense Confirmation
**Functionality:** Confirm deletion
**Type:** Alert (destructive)
**Title:** "Delete Expense?"
**Message:** "This will recalculate all balances. This cannot be undone."
**Actions:**
- Delete (Destructive)
- Cancel

---

### VII. DEBT & SETTLEMENT (14 Features)

#### 78. Auto Balance Calculation
**Functionality:** Real-time debt computation
**Trigger:** After every expense add/edit/delete
**Algorithm:**
1. Calculate each member's total spent
2. Calculate each member's total share of all expenses
3. Balance = Total Spent - Total Share

**Display:** Member balance in Member List and Trip Detail

#### 79. Debt Simplification (Min Cash Flow)
**Functionality:** Minimize number of transactions needed to settle
**Screen:** TripDetailView → Settlement Tab
**Algorithm:** Min Cash Flow graph algorithm
**Input:** Member balances (creditors and debtors)
**Output:** Optimal payment list

**Example:**
- Before: A→B: 50, A→C: 30, D→B: 20
- After: A→B: 50, D→C: 30, D→B: 20

**iOS Design:**
- Visual flow diagram (optional)
- Payment list with arrows

#### 80. User Total Balance
**Functionality:** Display user's net position in trip
**Location:** TripDetailView header
**Display:**
- Large amount (CurrencyLarge)
- Color-coded:
  - Green: "+Rp[amount] to collect"
  - Red: "-Rp[amount] to pay"
  - Gray: "All settled up ✓"

**iOS Design:**
- Card at top of Trip Detail
- Icon + color background
- Tap to see Settlement detail

#### 81. Payment Recommendations
**Functionality:** Show who should pay whom
**Screen:** SettlementView
**Display:** List of simplified payments
**Card Layout:**
- From (profile photo + name)
- Arrow icon →
- To (profile photo + name)
- Amount (CurrencyMedium)
- "Mark as Paid" button (if current user is "From")

**iOS Design:**
- Vertical list of payment cards
- Highlight user's own payments
- Action button only on relevant cards

#### 82. Bank Account Details
**Functionality:** Display payee's bank info
**Trigger:** Tap payment card → PaymentDetailView
**Display:**
- Bank name
- Account number (copy button)
- Account holder name
- QR code (if available)

**iOS Design:**
- Sheet presentation
- Copy to clipboard button
- Share button

#### 83. Upload Payment Proof
**Functionality:** Submit transfer evidence
**Trigger:** PaymentDetailView → "Upload Proof" button
**Options:**
- Take Photo
- Choose from Library

**File:** Image file (JPG/PNG), max 3MB
**Storage:** Firebase Storage

#### 84. Upload Success Alert
**Functionality:** Confirm proof submission
**Type:** Toast notification
**Message:** "Payment proof uploaded. Waiting for verification."
**State Change:** Payment status = Pending Verification

#### 85. Upload Missing Error
**Functionality:** Validation for proof upload
**Trigger:** Attempting to submit without file
**Response:** Alert "Please upload payment proof to continue."

#### 86. Verify Payment (Receiver)
**Functionality:** Confirm receipt of money
**Access:** Payment receiver only
**Screen:** SettlementView → Pending tab → Payment card
**Display:**
- Payment details
- Uploaded proof image (tap to zoom)
- Verify / Reject buttons

**iOS Design:**
- Action buttons at bottom
- Full-width proof image

#### 87. Reject Payment
**Functionality:** Dispute payment claim
**Trigger:** Verify screen → Reject button
**Required:** Rejection reason (text input)

#### 88. Rejection Reason Input
**Functionality:** Collect rejection context
**Screen:** Alert with text field
**Prompt:** "Please explain why you're rejecting this payment."
**Action:** Send notification to payer with reason

#### 89. Mark as Settled
**Functionality:** Confirm payment completion
**Trigger:** Verify screen → Verify button
**Action:**
- Update payment status = Settled
- Recalculate balances
- Update member balances
- Send confirmation notification

**Feedback:** Toast "Payment verified. Balances updated."

#### 90. Auto Balance Update
**Functionality:** Reflect settled payment in balances
**Trigger:** Payment verification
**Calculation:**
- Deduct amount from payer's debt
- Deduct amount from receiver's credit

**Display:** Updated balances in Member List and Trip header

#### 91. Settlement History
**Functionality:** View all past payments
**Screen:** SettlementView → History Tab
**List Display:**
- Date
- From → To
- Amount
- Status (Settled ✓)
- Proof thumbnail

**iOS Design:**
- Chronological list
- Tap for full detail
- Filter options (All, Sent, Received)

---

### VIII. REPORTS & NOTIFICATIONS (11 Features)

#### 92. Trip Summary
**Functionality:** Financial overview of trip
**Screen:** TripDetailView → Report Tab
**Metrics:**
- Total Expenses (large display)
- Your Total Spent
- Your Total Share
- Your Net Balance
- Number of Expenses
- Expense per Day (average)

**iOS Design:**
- Card-based layout
- Icons for each metric
- Color-coded amounts

#### 93. Category Pie Chart
**Functionality:** Visual expense breakdown
**Implementation:** Swift Charts
**Display:**
- Pie/Donut chart
- Category colors
- Percentage labels
- Legend below chart

**Interactive:**
- Tap segment to highlight
- Show category total on tap

#### 94. Export PDF Report
**Functionality:** Generate downloadable report
**Trigger:** Report Tab → Share button → "Export PDF"
**Content:**
- Trip details (name, dates, members)
- Total summary
- Category breakdown (chart + table)
- Expense list (detailed table)
- Settlement status

**Technology:** PDFKit
**Action:** Share sheet (Save, AirDrop, Email, etc.)

#### 95. Notification Inbox
**Functionality:** Central notification center
**Screen:** Tab Bar → Notifications (bell icon)
**Badge:** Unread count on tab icon
**List Display:**
- Type icon (color-coded)
- Title (Headline)
- Description (Subheadline)
- Timestamp (relative)
- Unread indicator (blue dot)

**iOS Design:**
- Inset grouped list
- Chronological order
- Swipe to delete
- Pull to refresh

#### 96. Trip Invitation Notification
**Functionality:** Alert for new trip invite
**Type:** Push + In-app
**Title:** "Trip Invitation"
**Body:** "[Name] invited you to [Trip Name]"
**Actions (in notification):**
- Accept button (Primary)
- Decline button (Secondary)
- View Details (navigates to trip preview)

**iOS Design:**
- Notification card in inbox
- Inline action buttons
- Trip thumbnail

#### 97. New Expense Notification
**Functionality:** Alert members when expense is added
**Type:** Push + In-app
**Title:** "New Expense in [Trip Name]"
**Body:** "[Name] paid Rp[amount] for [Expense Title]"
**Action:** Tap to view expense detail

#### 98. Payment Proof Notification
**Functionality:** Alert receiver of proof submission
**Type:** Push + In-app
**Title:** "Payment Proof Uploaded"
**Body:** "[Name] uploaded proof for Rp[amount] payment"
**Action:** Tap to verify payment

#### 99. Payment Verification Notification
**Functionality:** Confirm settlement to payer
**Type:** Push + In-app
**Title:** "Payment Verified ✓"
**Body:** "[Name] verified your payment of Rp[amount]"
**Action:** Tap to view settlement

#### 100. Highlight Unread
**Functionality:** Visual indicator for new notifications
**Display:**
- Blue dot on left side
- Bold title text
- Highlight background color (subtle)

**State:** Mark as read when tapped

#### 101. Mark as Read
**Functionality:** Clear unread status
**Trigger:** Tap notification
**Action:**
- Remove blue dot
- Decrease badge count
- Update database

**Batch Action:** "Mark All as Read" button at top

#### 102. Delete Notification
**Functionality:** Remove notification from list
**Trigger:** Swipe left → Delete
**Action:** Soft delete (archive) or hard delete
**Confirmation:** None (recoverable from archive)

---

### IX. ADMIN SYSTEM (8 Features)

#### 103. Admin Dashboard Statistics
**Functionality:** System-wide metrics overview
**Access:** Admin role only
**Screen:** AdminDashboardView (Settings → Admin)
**Metrics:**
- Total Users (with growth %)
- Total Trips (active + finished)
- Total Expenses
- Total Transaction Volume
- New Users (last 7 days)
- Active Users (MAU)
- Average Trip Size
- Platform Health (uptime, errors)

**iOS Design:**
- Grid layout (2 columns)
- Stat cards with icons
- Refresh timestamp
- Line charts for trends

#### 104. All Users List
**Functionality:** Browse all registered users
**Screen:** AdminDashboardView → Users Tab
**List Display:**
- Profile photo
- Name + username
- Email
- Status badge (Active/Suspended)
- Trips count
- Member since date

**iOS Design:**
- Inset grouped list
- Search bar
- Filter: All / Active / Suspended
- Tap for user detail

#### 105. Search Users (Admin)
**Functionality:** Find specific user
**Search Fields:** Name, username, email
**Real-time:** Filter as typing

#### 106. Suspend User
**Functionality:** Temporarily ban user
**Access:** Admin only
**Trigger:** UserDetailView → More menu → Suspend
**Effect:**
- User cannot login
- Push to suspended users rejected
- Existing sessions invalidated

**Confirmation Required:**
**Type:** Alert
**Title:** "Suspend [Name]?"
**Message:** "User will be logged out and unable to access the app."
**Input:** Reason for suspension (optional)
**Actions:** Suspend / Cancel

#### 107. Un-suspend User
**Functionality:** Restore user access
**Trigger:** UserDetailView → More menu → Activate
**Action:**
- Change status to Active
- Send email notification
- Log action

#### 108. Permanent User Delete
**Functionality:** Remove user and all data
**Access:** Admin only
**Trigger:** UserDetailView → More menu → Delete Permanently
**Effect:**
- Delete user account
- Remove from all trips
- Anonymize expense records ("Deleted User")
- Delete profile data

**Confirmation Required:**
**Type:** Alert (destructive)
**Title:** "Permanently Delete User?"
**Message:** "This will delete all user data. This action cannot be undone. Type '[username]' to confirm."
**Input:** Text field for username verification
**Actions:** Delete / Cancel

#### 109. All Trips List (Admin)
**Functionality:** Browse all trips in system
**Screen:** AdminDashboardView → Trips Tab
**List Display:**
- Trip name
- Owner name
- Member count
- Total expenses
- Status (Active/Finished)
- Created date

**iOS Design:**
- Inset grouped list
- Search and filter
- Sort options: Date, Members, Expenses
- Tap for trip detail

#### 110. Delete Problematic Trip
**Functionality:** Remove spam/abusive trips
**Access:** Admin only
**Trigger:** TripDetailView (Admin) → Delete
**Effect:**
- Delete trip and all expenses
- Notify all members
- Log admin action

**Confirmation Required:**
**Type:** Alert (destructive)
**Title:** "Delete Trip?"
**Message:** "This will permanently delete the trip for all members. Reason for deletion?"
**Input:** Text field for reason
**Actions:** Delete / Cancel

---

## Screen Map & Navigation Flow

### Primary Navigation (Tab Bar)

```
┌─────────────────────────────────────────┐
│  Trips   Expenses   Settlement   Notify  │ Profile
└─────────────────────────────────────────┘
    🏠        💰         ⚖️           🔔      👤
```

### Screen Hierarchy

```
Welcome (Unauthenticated)
├── Sign Up
├── Login
└── Forgot Password

Home (Trips Tab)
├── Active Trips
│   ├── Trip Detail
│   │   ├── Expenses Tab
│   │   │   ├── Add Expense (Manual)
│   │   │   ├── Scan Receipt
│   │   │   └── Expense Detail
│   │   ├── Members Tab
│   │   │   ├── Invite Members
│   │   │   └── Member Detail
│   │   ├── Settlement Tab
│   │   │   ├── Payment Detail
│   │   │   └── Verify Payment
│   │   └── Report Tab
│   │       └── Export PDF
│   └── Trip Settings
│       ├── Edit Trip
│       ├── Transfer Ownership
│       ├── Finish Trip
│       └── Delete Trip
└── History (Finished Trips)

Friends Tab
├── Friend List
├── Pending Requests
└── Search Users

Notifications Tab
├── All Notifications
└── Notification Settings

Profile Tab
├── Edit Profile
├── Change Password
├── Settings
│   ├── Notifications
│   ├── Privacy
│   └── Admin Dashboard (Admin only)
└── Logout
```

---

## User Flows

### Flow 1: Create Trip & Add First Expense

```
1. User opens app → Home (Trips)
2. Tap floating "+" button
3. CreateTripView opens (sheet)
4. Fill trip name, destination, dates
5. Tap "Create"
6. Trip created → Navigate to TripDetailView
7. Tap floating "+" on Expenses tab
8. Choose "Add Manually" or "Scan Receipt"
9. Fill expense details
10. Select split method (equally/by item)
11. Select members to split with
12. Tap "Save"
13. Expense saved → Return to expense list
14. Balances auto-calculated and displayed
```

### Flow 2: Settle Debt

```
1. User opens trip with negative balance
2. Navigate to Settlement tab
3. See payment recommendation: "You → Friend: Rp50,000"
4. Tap payment card
5. View bank details
6. Copy account number
7. Make bank transfer outside app
8. Return to app
9. Tap "Upload Proof"
10. Take photo of transfer receipt
11. Upload photo
12. Status changes to "Pending Verification"
13. Wait for friend to verify
14. Friend receives notification
15. Friend views proof and verifies
16. User receives confirmation notification
17. Balance updated to zero
```

### Flow 3: OCR Receipt Scan

```
1. User in TripDetailView → Expenses
2. Tap floating "+" → "Scan Receipt"
3. Camera opens
4. Point camera at receipt
5. Tap capture button
6. OCR processing (loading indicator)
7. Navigate to ScanPreviewView
8. Review extracted data:
   - Merchant name → Title
   - Total amount
   - Date
   - Line items
9. Edit any incorrect fields
10. Select category
11. Choose split method
12. Tap "Save"
13. Expense created with receipt photo
```

---

## Technical Specifications

### iOS SDK & Frameworks

```swift
// Core Frameworks
import SwiftUI               // UI Framework
import Combine               // Reactive programming

// Firebase
import FirebaseAuth          // Authentication
import FirebaseFirestore     // Database
import FirebaseStorage       // File storage
import FirebaseMessaging     // Push notifications

// iOS Native
import Vision                // OCR (receipt scanning)
import VisionKit             // Document scanning
import Charts                // Data visualization
import PDFKit                // PDF generation
import PhotosUI              // Photo picker
import UserNotifications     // Local notifications

// Third-party (Optional)
import Kingfisher            // Image caching
```

### Data Models

```swift
// User
struct User: Codable {
    var id: String
    var name: String
    var username: String
    var email: String
    var bio: String?
    var profilePhotoURL: String?
    var bankAccount: BankAccount?
    var role: UserRole  // user, owner, admin
    var status: AccountStatus  // active, suspended
    var createdAt: Date
}

// Trip
struct Trip: Codable {
    var id: String
    var name: String
    var destination: String
    var startDate: Date
    var endDate: Date
    var description: String?
    var coverPhotoURL: String?
    var ownerID: String
    var memberIDs: [String]
    var status: TripStatus  // active, finished
    var createdAt: Date
}

// Expense
struct Expense: Codable {
    var id: String
    var tripID: String
    var title: String
    var amount: Decimal
    var category: ExpenseCategory
    var date: Date
    var notes: String?
    var receiptPhotoURL: String?
    var paidBy: String  // userID
    var splitMethod: SplitMethod  // equally, byItem
    var splitDetails: [Split]
    var createdAt: Date
}

// Split
struct Split: Codable {
    var userID: String
    var amount: Decimal
    var items: [String]?  // for split by item
}

// Payment
struct Payment: Codable {
    var id: String
    var tripID: String
    var fromUserID: String
    var toUserID: String
    var amount: Decimal
    var proofPhotoURL: String?
    var status: PaymentStatus  // pending, verified, rejected
    var rejectionReason: String?
    var createdAt: Date
    var verifiedAt: Date?
}

// Notification
struct AppNotification: Codable {
    var id: String
    var userID: String
    var type: NotificationType
    var title: String
    var body: String
    var relatedID: String?  // tripID, expenseID, etc.
    var isRead: Bool
    var createdAt: Date
}
```

### Firestore Collections

```
/users/{userID}
/trips/{tripID}
/trips/{tripID}/members/{userID}
/trips/{tripID}/expenses/{expenseID}
/trips/{tripID}/payments/{paymentID}
/friendships/{friendshipID}
/friendRequests/{requestID}
/tripInvitations/{invitationID}
/notifications/{notificationID}
/adminLogs/{logID}
```

---

## iOS Design Guidelines Compliance

### Human Interface Guidelines (HIG)

**Navigation:**
- Use standard iOS navigation patterns
- Tab bar for primary navigation (max 5 tabs)
- Navigation bar for hierarchical navigation
- Modal sheets for temporary tasks

**Typography:**
- San Francisco font system
- Dynamic Type support for accessibility
- Semantic text styles (Large Title, Title, Body, etc.)

**Colors:**
- Support Light Mode and Dark Mode
- Use semantic colors (label, secondaryLabel, etc.)
- Consistent with iOS system colors
- High contrast ratios for accessibility (WCAG AA)

**Layout:**
- Safe area insets respected
- Adaptive layout for different device sizes
- iPad support with split view (V2)
- Landscape orientation support

**Interactions:**
- Standard gestures (tap, swipe, long press)
- Pull to refresh on lists
- Swipe actions on list items
- Haptic feedback for important actions

**Accessibility:**
- VoiceOver support
- Dynamic Type
- High contrast mode
- Reduce Motion support

---

## Success Metrics & KPIs

### User Engagement
- **MAU (Monthly Active Users):** Target 10,000+ in 6 months
- **DAU/MAU Ratio:** Target 40%+ (high engagement)
- **Session Length:** Average 5-8 minutes per session
- **Sessions per User:** 15-20 per month

### Feature Adoption
- **Trips Created:** 5+ per user on average
- **Expenses Logged:** 20+ per trip on average
- **OCR Usage Rate:** 60%+ of expenses use scanning
- **Settlement Completion Rate:** 90%+ of debts settled

### Retention
- **Day 1 Retention:** 60%+
- **Day 7 Retention:** 40%+
- **Day 30 Retention:** 25%+
- **Churn Rate:** <10% monthly

### Performance
- **App Launch Time:** <2 seconds
- **OCR Processing:** <5 seconds per receipt
- **Expense Save Time:** <1 second
- **Crash-Free Rate:** 99.5%+

### User Satisfaction
- **App Store Rating:** 4.5+ stars
- **NPS Score:** 50+
- **Support Tickets:** <5% of users contact support

---

## Development Roadmap

### Phase 1: MVP (8-10 weeks)
**Week 1-2:** Authentication & Profile
- Sign up, login, forgot password
- Profile management
- Friend system basics

**Week 3-4:** Trip Management
- Create/edit/delete trips
- Invite members
- Member management

**Week 5-6:** Expense Tracking
- Manual expense entry
- Split equally/by item
- Expense list and detail views

**Week 7:** Settlement
- Balance calculation
- Min cash flow algorithm
- Payment proof upload

**Week 8:** Reports & Notifications
- Trip summary
- Category charts
- Push notifications

**Week 9-10:** Testing & Polish
- Bug fixes
- Performance optimization
- UI refinement

### Phase 2: Enhanced Features (6-8 weeks)
- OCR receipt scanning (Vision framework)
- PDF report export
- Admin dashboard
- Enhanced notifications
- Dark mode optimization

### Phase 3: Advanced Features (8-10 weeks)
- Multi-currency support
- Offline mode with sync
- AI spending insights
- Shared itinerary
- Expense recurring patterns

---

## Risk Mitigation

### Technical Risks
- **OCR Accuracy:** Fallback to manual entry always available
- **Network Issues:** Cache data locally, sync when online
- **Payment Disputes:** Clear rejection reason system + manual resolution
- **Data Loss:** Automatic Firestore backups + Firebase redundancy

### Business Risks
- **Low Adoption:** Referral incentives, social sharing features
- **Privacy Concerns:** Clear privacy policy, data encryption
- **Competition:** Focus on iOS-native experience superiority
- **Scaling Costs:** Firebase pricing tier monitoring, optimization

---

## Appendix

### Glossary
- **Trip Owner:** User who created the trip, has full management rights
- **Balance:** Net amount (spent - share), positive = owed to you, negative = you owe
- **Debt Simplification:** Algorithm to minimize number of payment transactions
- **Split Equally:** Divide expense evenly among selected members
- **Split by Item:** Assign specific receipt items to specific members
- **Settlement:** Process of paying back debts
- **Payment Proof:** Photo evidence of bank transfer

### References
- Apple Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines/
- SwiftUI Documentation: https://developer.apple.com/documentation/swiftui
- Firebase iOS SDK: https://firebase.google.com/docs/ios/setup
- Vision Framework: https://developer.apple.com/documentation/vision

---

**Document Version:** 1.0
**Last Updated:** 2026-04-27
**Author:** TripLedger Product Team
**Status:** Ready for Design & Development
