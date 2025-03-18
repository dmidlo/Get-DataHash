# **`DataHash` - A PowerShell Object Hashing Utility**  

***Powershell 7+***

## **The Origin Story**  
Originally developed as part of a **LiteDB-backed version control system**, `DataHash` started as a **behind-the-scenes workhorse**, ensuring structured data could be **reliably tracked for changes**.  

It sat quietly in its directory, **efficiently computing message digests, detecting differences, and preventing unnecessary writes**—until it became clear that its functionality was **too useful to remain siloed** in a single project.

Now, `DataHash` is breaking out of its original home, standing on its own as a **general purpose** PowerShell 7+ hashing utility. ***Its mission remains the same***:
- ✅ **Provide fast, deterministic message digests** for structured PowerShell Objects.
- ✅ **Enable lightweight, persistent change tracking** in any PowerShell-Based system.

🚀 ***Now it's out of its original home, transformed from a bunch of disjoint scripts into a single concise object.

---

## **Designed for Stability, Predictability, and Confidence**  

One of the primary design goals of `DataHash` is to ensure that **message digests remain stable across runs**. Developers rely on hashing functions to track changes, enforce cache consistency, and detect duplicates. A digest that **changes unpredictably** would be **worse than useless—it would create false positives** in every comparison.  

To achieve **stable, predictable message digests**, `DataHash` follows these key principles:  

🔹 **Sorts unordered collections** – Dictionaries (`@{}`) and hash tables are sorted **by key** to ensure consistent order before computing the digest.  

🔹 **Preserves ordered collections** – If an **ordered dictionary** (`[ordered]@{}`) or an **ordered list** (like a `Queue`, `Stack`, or `List<T>`) is provided, its original order is maintained.  

🔹 **Handles circular references** gracefully – Self-referencing objects are marked as `"[CIRCULAR_REF]"` in the pre-hash structure, ensuring unique object identity if the reference is not present later. Also prevents infinite loops... which is pretty useful too.

🔹 **Normalizes floating-point values** – Converts them to **IEEE 754 consistent string representations** (`"G17"` format) to ensure **cross-platform** and **cross-runtime** consistency.  

🔹 **Ignores explicitly excluded fields** – Developers can **exclude volatile fields** (like timestamps, session IDs, or request tracking fields) to maintain **consistent digests** even as values change.  

🔹 **Encapsulates serialization logic with LiteDB** – BSON serialization ensures structured data (e.g., `PSCustomObject`, `Hashtable`) is **hashed consistently** without being affected by PowerShell’s native JSON quirks (e.g., trailing zeros in floats, unquoted property names).  

---

## **A Note on Message Digests vs. Cryptographic Security**  

`DataHash` computes **message digests**—fixed-length fingerprints of structured data, designed for **tracking changes, caching, and deduplication**.  

🔹 **Message digests are deterministic** → The same input will always produce the same output.  
🔹 **They do not include cryptographic salt** → This is intentional for consistency in state tracking.  
🔹 **They can be used in cryptographic workflows** → If needed, they can be **signed, encrypted, or combined with HMAC** for authentication.  

This is not a **password hashing** tool, nor does it provide **message authentication** on its own. If you need to verify **authenticity and integrity in security-critical applications**, consider **HMAC (e.g., HMAC-SHA-256)** or **digital signatures**.  

---

## **Constructor Usage**  

```powershell
# Create a new instance (manual hashing later)
$hashInstance = [DataHash]::new()

# Generate a message digest from an object
$hash = [DataHash]::new($object)
Write-Output $hash.Hash

# Compute a digest while ignoring specific fields
$ignoreFields = [HashSet[string]]::new(@("Timestamp", "SessionID"))
$hash = [DataHash]::new($object, $ignoreFields)

# Specify a custom hashing algorithm
$hash = [DataHash]::new($object, $ignoreFields, "SHA512")
```

---

## **📝 Where It Shines**  

### **🔄 Version Control for PowerShell Data Structures**  
The original project proved `DataHash` could **reliably track changes** to structured data stored in LiteDB. Now, it can do the same in **any PowerShell-based version control or state-tracking system**.  

```powershell
$previousState = [DataHash]::new($storedObject)
$currentState = [DataHash]::new($incomingObject)

if ($previousState -ne $currentState) {
    Write-Output "Data has changed! Recording new version..."
    Save-DataToLiteDB $incomingObject
}
```

With `DataHash`, you don’t need to store **entire copies of objects**—just store their message digests and detect changes efficiently.  

---

### **🚀 Caching for Pode & Pode.Web**  
One of the simplest ways to **reduce unnecessary backend processing** in a Pode web app is to **cache** responses using message digests as keys.  

```powershell
$apiResponse = Invoke-RestMethod -Uri "https://api.example.com/data"
$cacheKey = [DataHash]::new($apiResponse)

if (-not (Test-Path "cache\$cacheKey.json")) {
    Write-Output "Caching new API response..."
    $apiResponse | ConvertTo-Json | Set-Content "cache\$cacheKey.json"
}
```

This avoids **unnecessary API calls** and speeds up response times.  

---

### **📜 Audit Logging & Compliance in Azure EntraID**  
**Managing Microsoft EntraID** sometimes requires **historical tracking of group memberships, role assignments, and user attributes**. Instead of storing **full snapshots**, store **message digests** to detect changes efficiently.  

```powershell
# Fetch group members using Microsoft Graph API
$groupId = "xxxx-xxxx"
$adGroup = Get-MgGroupMember -GroupId $groupId | Select-Object DisplayName, Id

# Compute a message digest of the current state
$groupDigest = [DataHash]::new($adGroup)

# Compare with the last known digest stored in your audit log database
if ($groupDigest -ne (Get-PreviousDigestFromDatabase)) {
    Write-Output "Entra ID Group membership has changed! Logging..."
    Save-ToAuditLog $adGroup
}
```

By storing **only digests**, you reduce **storage overhead** while still tracking **historical changes**.  

---

### **🔍 Preventing Duplicate Processing in Azure Automation**  
If an **Azure Automation runbook** processes thousands of items, you want to **skip duplicates**.  

```powershell
$itemDigest = [DataHash]::new($dataItem)

if (-not (Test-Path "processed\$itemDigest.txt")) {
    Write-Output "New item detected. Processing..."
    Process-Item $dataItem
    New-Item "processed\$itemDigest.txt" -ItemType File
}
```

This avoids **re-processing the same data**, improving efficiency.  

---
Gotcha! Let’s swap out the **circular reference** example for something way cooler—something **practical, unique, and shows off `DataHash`’s real-world power**.  

How about **tamper detection in PowerShell scripts**? We can **hash a script’s content**, store the digest, and later verify if it has been altered—perfect for security monitoring, CI/CD pipelines, or compliance.  

---

### **🛡️ Detecting Script Tampering & Unauthorized Changes**  
PowerShell scripts control **critical automation, deployments, and security tasks**. But what if someone **modifies a script**—intentionally or accidentally?  

With `DataHash`, you can **generate a fingerprint** of your scripts and detect unauthorized changes.  

```powershell
# Compute a message digest of a PowerShell script
$scriptPath = "C:\Automation\Deploy.ps1"
$scriptContent = Get-Content -Path $scriptPath -Raw
$scriptDigest = [DataHash]::new($scriptContent)

# Compare with the last known digest stored in a secure location
$previousDigest = Get-Content -Path "C:\Automation\Deploy.ps1.hash"

if ($scriptDigest -ne $previousDigest) {
    Write-Output "🚨 Warning: Script has been modified! Investigate immediately."
    Send-Alert -Message "Deploy.ps1 has been altered!" -Severity High
} else {
    Write-Output "✅ Script integrity verified."
}
```

**Instantly detect unauthorized changes** and Protects against accidental edits or tampering. **Integrates with security monitoring** and Send alerts if a critical script changes.  

---

### **🎯 Comparing Object States for Change Detection**  
Using `DataHash`, you can **quickly compare versions of an object** to determine whether a change has occurred.  

```powershell
$oldVersion = [DataHash]::new($objectV1)
$newVersion = [DataHash]::new($objectV2)

if ($oldVersion -eq $newVersion) {
    Write-Output "No changes detected."
} else {
    Write-Output "Object has changed, updating record..."
}
```

Instead of **manually diffing object properties**, let `DataHash` generate **a reliable digest** for quick comparisons.  

---

🔹 **Designed for structured data** – Handles objects, dictionaries, lists, and more.  
🔹 **Built for efficiency** – Detects changes without storing entire object copies.  
🔹 **Works anywhere PowerShell does** – Use it in **APIs, automation, auditing, and caching**.  

If you're **tracking changes, enforcing caching, or comparing object states**, `DataHash` is your **best friend** in PowerShell. 🔥  

---

### **Best Practices for Using `DataHash` in PowerShell Projects**  

✔ **Leverage field exclusions** to maintain consistent digests across updates.  
✔ **Choose the right hashing algorithm** for your needs (`SHA256` for balance, `SHA512` for longer-term integrity).  
✔ **Use `DataHash` for caching, deduplication, and change tracking**—it is **not a password hashing or authentication tool**.  

---

## **Why `DataHash` Uses LiteDB for BSON Serialization**  

PowerShell’s built-in `ConvertTo-Json` has a problem—it **silently changes data** (trailing zeros, type coercion, property reordering). That’s unacceptable for hashing. Instead, we went with **LiteDB’s BSON serialization**, and here’s why:  

🔹 **Ultra-lightweight** – Perfect for **Pode, Pode.Web, and automation workflows**—no unnecessary overhead.  
🔹 **Actively maintained** – Predictable updates and long-term reliability.  
🔹 **Precision BSON serialization** – **Prevents PowerShell’s type inconsistencies** from corrupting hashes.  
🔹 **Custom serialization support** – Extend hashing to **custom PowerShell types** with LiteDB’s `BsonMapper`.  

By leveraging **BSON instead of JSON**, `DataHash` ensures every digest is **stable and predictable**, even across different PowerShell versions and environments.  

### **Do we store data in LiteDB, is that how this gets done?
No! we don't even store the input object within the instance of [DataHash]. We're using two-thirds of the LiteDB library, as a ***lightweight implementation of the BSON standard***, we leverage BSON, BSON Serialization, and Custom Type Mapping from LiteDB.

### **Need to hash custom PowerShell objects? No problem.**  
With **LiteDB’s `BsonMapper`**, you can **define exactly how your custom types serialize**, ensuring `DataHash` generates **consistent, structured digests** for your unique data models.  

🚀 **Bottom line?** `DataHash` doesn’t just hash objects—it does it **the right way**, with **full control over serialization**.  

## Behavior Examples


## **🛠️ Power Moves with `DataHash`**  
`DataHash` isn’t just a simple hashing utility—it’s **built for real-world use cases**, with smart ways to **handle edge cases, customize behavior, and work seamlessly with PowerShell objects**.  

Here are some **awesome techniques** you can use right now:  

---

### **🔹 Ignoring Fields to Keep Hashes Stable**  
Some fields **change constantly** (timestamps, session IDs, dynamic counters). `DataHash` lets you **ignore specific fields** so your message digest stays stable when those values shift.  

```powershell
$DataHash = [DataHash]::New()
$DataHash.IgnoreFields.Add('Timestamp')  # Ignore volatile fields

$logEntry = @{ User = "Alice"; Action = "Login"; Timestamp = (Get-Date) }

$hash = $DataHash.Digest($logEntry, "SHA256")
Write-Output "Digest without Timestamp: $hash"
```

✅ **Why this is awesome?**  
- Hash **stays the same** even if `Timestamp` changes.  
- Great for **change tracking** when only certain fields matter.  

---

### **🔹 Hashing `PSCustomObject` Just Like a Dictionary**  
PowerShell objects aren’t **just hashtables**, but `DataHash` makes them **work like one** for consistent hashing.  

```powershell
$DataHash = [DataHash]::New()
$user = [PSCustomObject]@{ Name = "John"; Age = 30 }

$hash = $DataHash.Digest($user, "SHA256")
Write-Output "User Digest: $hash"
```

💡 **What’s happening here?**  
- Properties are treated **like dictionary keys**.  
- Hash order is **sorted alphabetically** to stay **consistent across runs**.  

---

### **🔹 Keeping Order in Ordered Dictionaries**  
Unlike normal dictionaries, **ordered dictionaries matter**—and `DataHash` **respects that**.  

```powershell
$DataHash = [DataHash]::New()
$orderedDict = [ordered]@{ C = 1; A = 2; B = 3 }

$hash = $DataHash.Digest($orderedDict, "SHA256")
Write-Output "Ordered Dictionary Digest: $hash"
```

✅ **Order is preserved!**  
- Great for **tracking exact list structures**.  
- Unlike unordered dictionaries, this **won’t sort keys** before hashing.  

---

### **🔹 Preserving Ordered Dictionaries Inside Unordered Ones**  
What if you have a **mix** of ordered and unordered dictionaries? `DataHash` **sorts what it should and leaves the rest alone**.  

```powershell
$DataHash = [DataHash]::New()
$complexDict = @{
    OrderedPart = [ordered]@{ B = 2; A = 1 }
}

$hash = $DataHash.Digest($complexDict, "SHA256")
Write-Output "Nested Ordered Dictionary Digest: $hash"
```

💡 **Why this matters?**  
- `DataHash` **sorts unordered dictionaries** but **preserves explicit order** inside `[ordered]@{}`.  
- Perfect for **structured data that needs strict order**.  

---

### **🔹 Normalizing Nested Dictionaries (Recursively!)**  
Nested dictionaries? **No problem**. `DataHash` **walks the structure, sorts keys, and keeps everything consistent**.  

```powershell
$DataHash = [DataHash]::New()
$nestedDict = @{
    Outer = @{
        Inner2 = 200
        Inner1 = 100
    }
}

$hash = $DataHash.Digest($nestedDict, "SHA256")
Write-Output "Nested Dictionary Digest: $hash"
```

✅ **Always predictable, always stable.**  

---

### **🔹 Hashing Data with `Null` Values**  
Sometimes, data has `null` values—**but we still need them to hash correctly**. `DataHash` **normalizes them** instead of ignoring them.  

```powershell
$DataHash = [DataHash]::New()
$testDict = @{ Key1 = $null }

$hash = $DataHash.Digest($testDict, "SHA256")
Write-Output "Digest of Object with Null: $hash"
```

💡 **How does it work?**  
- `DataHash` replaces `null` with a **consistent marker (`"[NULL]"`)**.  
- Ensures `null` values don’t get silently skipped.  

---

# **🛠️ Power Moves with `DataHash` – List Normalization Like a Pro**  

PowerShell doesn’t always play nice when it comes to **lists, sets, and mixed data structures**. But `DataHash`? It **handles all of that like a champ**—preserving order where it matters, sorting unordered collections, and keeping everything **stable across runs**.  

Here’s how to **take full advantage of `DataHash`'s list normalization magic**:  

---

### **🔹 Preserving Order in Lists**  
Ordered lists **stay ordered**, so you can **track changes reliably** without unnecessary re-sorting.  

```powershell
$DataHash = [DataHash]::New()
$orderedList = [System.Collections.Generic.List[object]]@("A", "B", "C")

$hash = $DataHash.Digest($orderedList, "SHA256")
Write-Output "Ordered List Digest: $hash"
```

✅ **Perfect for:**  
- **Tracking user-defined lists** (e.g., preference settings).  
- **Preserving execution order** in workflow automation.  

---

### **🔹 Sorting Unordered Collections Deterministically**  
Unordered collections (like **HashSets**) get **sorted automatically**, ensuring that **the same data always produces the same digest—regardless of input order**.  

```powershell
$DataHash = [DataHash]::New()
$unorderedSet = [System.Collections.Generic.HashSet[object]]::new(@("B", "A", "C"))

$hash = $DataHash.Digest($unorderedSet, "SHA256")
Write-Output "Unordered Set Digest: $hash"
```

✅ **Why this matters?**  
- **Eliminates randomness** when hashing unordered data.  
- **Ensures consistency in caching, deduplication, and state tracking**.  

---

### **🔹 Handling Mixed Data Types in Lists**  
Got **strings, numbers, booleans, and floats all in one list**? No problem. `DataHash` **handles them consistently**—ensuring cross-platform and cross-runtime stability.  

```powershell
$DataHash = [DataHash]::New()
$mixedList = @(42, "Test", $true, 3.14)

$hash = $DataHash.Digest($mixedList, "SHA256")
Write-Output "Mixed Data List Digest: $hash"
```

✅ **What’s happening?**  
- `true`, `false`, and `42` are **kept as-is**.  
- `3.14` is **normalized** to a precise IEEE 754 **floating-point representation**.  

---

### **🔹 Hashing Nested Lists with Confidence**  
Deeply nested lists **retain their structure**, while unordered sub-lists **get sorted**—so you never get **unexpected hash changes**.  

```powershell
$DataHash = [DataHash]::New()
$nestedList = @(1, @(2, 3), 4)

$hash = $DataHash.Digest($nestedList, "SHA256")
Write-Output "Nested List Digest: $hash"
```

✅ **Why this is powerful?**  
- **Maintains nested list hierarchy** for structured data.  
- **Ensures consistent results across different PowerShell versions.**  

---

### **🔹 Sorting an Unordered Object Nested Inside an Ordered One**  
Sometimes, **part of your data needs sorting, but part of it doesn’t**. `DataHash` gets it right.  

```powershell
$DataHash = [DataHash]::New()
$unorderedNestedSet = [System.Collections.Generic.HashSet[object]]::new(@(3, 2))
$orderedUnordered = @(1, $unorderedNestedSet, 4)

$hash = $DataHash.Digest($orderedUnordered, "SHA256")
Write-Output "Sorted Nested Unordered Data Digest: $hash"
```

✅ **What happens here?**  
- `@(1, @(3, 2), 4)` → Becomes `@(1, @(2, 3), 4)` (inner list is sorted).  
- **The top-level list order is preserved!**  

---

### **🔹 Keeping Order When Ordered Lists Are Nested**  
If **both parent and child lists are ordered**, `DataHash` **leaves them alone**.  

```powershell
$DataHash = [DataHash]::New()
$orderedNestedList = [System.Collections.Generic.List[object]]::new(@(3, 2))
$orderedOrdered = @(1, $orderedNestedList, 4)

$hash = $DataHash.Digest($orderedOrdered, "SHA256")
Write-Output "Nested Ordered List Digest: $hash"
```

✅ **Why does this matter?**  
- Some lists **must** stay in the exact order (e.g., **transaction logs, ordered dependencies**).  
- `DataHash` **preserves order where it makes sense**.  

---

### **🔹 Sorting an Unordered Parent List While Keeping Ordered Nested Lists Intact**  
Mixing **unordered and ordered data**? `DataHash` **knows which to sort and which to leave alone**.  

```powershell
$DataHash = [DataHash]::New()
$orderedNestedList = [System.Collections.Generic.List[object]]::new(@(3, 2))
$unorderedOrdered = [System.Collections.Generic.HashSet[object]]::new(@(4, $orderedNestedList, 1))

$hash = $DataHash.Digest($unorderedOrdered, "SHA256")
Write-Output "Unordered Parent, Ordered Child Digest: $hash"
```

✅ **What happens?**  
- Parent list is **sorted**: `@(1, 4, @(3, 2))`.  
- Inner ordered list is **kept intact**.  

---

### **🔹 Normalizing Floating Point Numbers for Precision**  
Floats can be **messy** in PowerShell—but `DataHash` **ensures numerical consistency** across platforms.  

```powershell
$DataHash = [DataHash]::New()
$floatList = @(3.14, 2.71)

$hash = $DataHash.Digest($floatList, "SHA256")
Write-Output "Floating Point Digest: $hash"
```

✅ **Why does this matter?**  
- PowerShell **sometimes drops trailing zeros or rounds floats unpredictably**.  
- `DataHash` **ensures IEEE 754 precision** by **normalizing floating points consistently**.  

---

### **🔹 Hashing Lists That Contain Boolean Values**  
Booleans (`$true/$false`) **are preserved exactly**, so you get **precise, repeatable digests**.  

```powershell
$DataHash = [DataHash]::New()
$boolList = @($true, $false, $true)

$hash = $DataHash.Digest($boolList, "SHA256")
Write-Output "Boolean List Digest: $hash"
```

✅ **Why this is useful?**  
- Boolean flags **matter in state tracking**—they **shouldn’t get coerced into numbers (`1/0`)**.  
- `DataHash` **keeps booleans explicit**, so `true` ≠ `1`.  

---

# **🛠️ Mastering `DataHash` – Power Moves with Constructors**  

## **🔹 Generate a Message Digest from Any Object Instantly**  
You don’t need to **pre-process or serialize** anything—just pass your object, and `DataHash` handles the rest.  

```powershell
$object = @{ Name = "John"; Age = 30 }
$hashObj = [DataHash]::new($object)

Write-Output "Object Digest: $($hashObj.Hash)"
```

✅ **Works with:**  
- **Hashtables**, **PSCustomObjects**, **arrays**, and even **complex nested structures**.  
- **Consistently produces the same digest** for the same input, across runs.  

---

## **🔹 Ignore Specific Fields to Keep Hashes Stable**  
Sometimes, you need to **exclude volatile fields** (timestamps, session IDs, etc.) so your hash **only changes when meaningful data changes**.  

```powershell
$object = @{ User = "Alice"; SessionID = "XYZ123" }
$ignoreFields = [System.Collections.Generic.HashSet[string]]::new(@("SessionID"))

$hashObj = [DataHash]::new($object, $ignoreFields)

Write-Output "Stable Digest: $($hashObj.Hash)"  # Ignores SessionID changes
```

✅ **Why this is awesome?**  
- Prevents **session-based or temporary data** from breaking hash consistency.  
- Great for **change tracking, deduplication, and caching**.  

---

## **🔹 Choose Your Hashing Algorithm**  
Need **MD5 for legacy compatibility**, **SHA256 for general use**, or **SHA512 for maximum security**? `DataHash` lets you pick.  

```powershell
$object = @{ Data = "SecureContent" }

$hashMD5 = [DataHash]::new($object, $null, "MD5")
$hashSHA512 = [DataHash]::new($object, $null, "SHA512")

Write-Output "MD5 Digest: $($hashMD5.Hash)"
Write-Output "SHA512 Digest: $($hashSHA512.Hash)"
```

✅ **Choose the right tool for the job:**  
- **MD5** → 🔥 **Fast but weak** (use for non-security-related deduplication).  
- **SHA256** → 🛡️ **Balanced security & speed** (great default choice).  
- **SHA512** → 🔒 **Higher security, longer hash** (for cryptographic workflows).  

---

## **🔹 Handle Complex Nested Objects Effortlessly**  
`DataHash` isn’t just for flat data—it **dives deep into nested objects** and ensures consistent hashing.  

```powershell
$complexObject = @{
    User = @{
        Name = "Alice"
        Details = @{ ID = 123; Email = "alice@example.com" }
    }
    Roles = @("Admin", "Editor")
}

$hashObj = [DataHash]::new($complexObject)

Write-Output "Nested Object Digest: $($hashObj.Hash)"
```

✅ **What happens?**  
- **Dictionaries get sorted** before hashing (so key order doesn’t affect results).  
- **Arrays stay in order** (so order-sensitive data remains stable).  
- **Deeply nested structures are handled automatically**—no extra work needed.  

---

## **🔹 Hash Empty Dictionaries & Collections Safely**  
Even **empty objects** need a stable digest. `DataHash` **ensures that empty collections are still processed correctly**.  

```powershell
$hashEmptyDict = [DataHash]::new(@{})
$hashEmptyArray = [DataHash]::new(@())

Write-Output "Empty Dictionary Digest: $($hashEmptyDict.Hash)"
Write-Output "Empty Array Digest: $($hashEmptyArray.Hash)"
```

✅ **Why this matters?**  
- **Prevents null reference errors** when hashing empty objects.  
- **Ensures empty collections always produce a consistent digest.**  

---

## **🔹 Handle `null` Input Gracefully**  
What happens if someone **accidentally passes `$null`**? `DataHash` has **your back**.  

```powershell
try {
    $hashNull = [DataHash]::new($null)
} catch {
    Write-Output "Expected Error: $_"
}
```

✅ **Why this is useful?**  
- **Prevents accidental hashing of `null` values**.  
- **Ensures data integrity** by enforcing input validation.  

---

# **🚀 Why These Features Matter**  
🔹 **Handles any PowerShell data structure** – Lists, objects, nested dictionaries—you name it.  
🔹 **Adapts to your needs** – Ignore volatile fields, pick your hash algorithm, and handle circular references seamlessly.  
🔹 **Eliminates serialization quirks for perfect consistency** – No unexpected changes, just **pure deterministic hashing**.  
