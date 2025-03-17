# **`DataHash` - A Battle-Tested PowerShell Hashing Utility**  

***Powershell 7+***

## **The Origin Story**  
Originally developed as part of a **LiteDB-backed version control system**, `DataHash` started as a **behind-the-scenes workhorse**, ensuring structured data could be **reliably tracked for changes**.  

It sat quietly in its directory, **efficiently computing message digests, detecting differences, and preventing unnecessary writes**—until it became clear that its functionality was **too useful to remain siloed** in a single project.  

Now, `DataHash` is breaking out of its original home, standing on its own as a **general-purpose PowerShell hashing utility**. Its **mission remains the same**:  
✅ **Provide fast, deterministic message digests** for structured PowerShell objects.  
✅ **Enable lightweight, persistent change tracking** in any PowerShell-based system.  
🚀 **Now it's out of its original home, and ready to be used wherever you need it!**  
---

## **Designed for Stability, Predictability, and Confidence**  

One of the primary design goals of `DataHash` is to ensure that **message digests remain stable across runs**. Developers rely on hashing functions to track changes, enforce cache consistency, and detect duplicates. A digest that **changes unpredictably** would be **worse than useless—it would create false positives** in every comparison.  

To achieve **stable, predictable message digests**, `DataHash` follows these key principles:  

🔹 **Sorts unordered collections** – Dictionaries (`@{}`) and hash tables are sorted **by key** to ensure consistent order before computing the digest.  

🔹 **Preserves ordered collections** – If an **ordered dictionary** (`[ordered]@{}`) or an **ordered list** (like a `Queue`, `Stack`, or `List<T>`) is provided, its original order is maintained.  

🔹 **Handles circular references** gracefully – Self-referencing objects are marked as `"[CIRCULAR_REF]"`, ensuring infinite loops **never** cause failures.  

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
One of the simplest ways to **reduce unnecessary processing** in a Pode web app is to **cache** responses using message digests as keys.  

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
Azure Active Directory (now **EntraID**) requires **historical tracking of group memberships, role assignments, and user attributes**. Instead of storing **full snapshots**, store **message digests** to detect changes efficiently.  

```powershell
$adGroup = Get-AzADGroupMember -GroupObjectId "xxxx-xxxx" | Select-Object DisplayName, Id
$groupDigest = [DataHash]::new($adGroup)

if ($groupDigest -ne (Get-PreviousDigestFromDatabase)) {
    Write-Output "EntraID Group membership has changed! Logging..."
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

### **🌀 Handling Circular References Gracefully**  
The `DataHash` class **automatically detects** circular references, preventing infinite loops while maintaining object integrity.  

```powershell
$node = @{ Name = "A" }
$node["Self"] = $node  # Circular reference

$hash = [DataHash]::new($node)
Write-Output "Generated Digest: $($hash.Hash)"  # Handles self-referencing structures safely
```

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

### **Final Thoughts on Where It Shines**  
🔹 **Designed for structured data** – Handles objects, dictionaries, lists, and more.  
🔹 **Built for efficiency** – Detects changes without storing entire object copies.  
🔹 **Works anywhere PowerShell does** – Use it in **APIs, automation, auditing, and caching**.  

If you're **tracking changes, enforcing caching, or comparing object states**, `DataHash` is your **best friend** in PowerShell. 🔥  

---

How's that? Kept it sharp, to the point, and still engaging. 😎 Let me know if you'd like any tweaks!

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

### **Need to hash custom PowerShell objects? No problem.**  
With **LiteDB’s `BsonMapper`**, you can **define exactly how your custom types serialize**, ensuring `DataHash` generates **consistent, structured digests** for your unique data models.  

🚀 **Bottom line?** `DataHash` doesn’t just hash objects—it does it **the right way**, with **full control over serialization**.  
