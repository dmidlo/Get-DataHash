## **1. Scope**  

This document establishes the functional, structural, and operational specifications for the `DataHash` class, a PowerShell implementation designed to generate deterministic cryptographic hashes from objects. It ensures stable, reproducible hash outputs across diverse data structures while handling nested elements, circular references, and unordered collections.  

## **2. Normative References**  

The implementation conforms to the following standards:  

- **ISO/IEC 10118-3**:2004 – Hash functions (MD5, SHA-1, SHA-2)  
- **ISO/IEC 27002**:2022 – Information Security Controls (Cryptographic Practices)  
- **ISO/IEC 19514**:2017 – Object Modeling and Serialization Best Practices  

## **3. Terms and Definitions**  

- **Hash Function**: A cryptographic function mapping data of arbitrary size to a fixed-size value.  
- **Deterministic Hashing**: A hashing approach ensuring that identical inputs produce identical outputs across executions.  
- **Circular Reference**: A data structure where an object references itself, either directly or indirectly.  
- **Ordered Collection**: A data structure preserving element order (e.g., Lists, Queues).  
- **Unordered Collection**: A data structure without guaranteed element order (e.g., Hashtables).  

## **4. Functional Overview**  

### **4.1 Purpose**  
The `DataHash` class facilitates deterministic hashing of complex objects, ensuring structural integrity and handling diverse object types. It supports:  

- **Nested Objects**: Ensuring deep structural hashing.  
- **Ordered vs. Unordered Collections**: Sorting unordered collections for stable results.  
- **Circular Reference Detection**: Detects when an object contains a self-reference and replaces the value with `"[CIRCULAR_REF]"` instead of skipping it, ensuring object identity is still represented as self-referencing.
- **Field Exclusions**: Allowing selective omission of object fields.  
- **Configurable Hash Algorithms**: Supporting MD5, SHA-1, SHA-256, SHA-384, and SHA-512.  

### **4.2 Supported Hash Algorithms**  

The class supports the following cryptographic hash functions, as defined in `DataHashAlgorithmType`:  

| **Algorithm** | **Bit Length** | **Security Level** | **Recommended Usage** |
|--------------|--------------|-------------------|----------------------|
| MD5         | 128          | Weak (Collision-Prone) | Not recommended |
| SHA-1       | 160          | Weak (Collision-Prone) | Not recommended |
| SHA-256     | 256          | Strong | General use |
| SHA-384     | 384          | Strong | High-security applications |
| SHA-512     | 512          | Very Strong | Cryptographic operations |

## **5. Structural Composition**  

### **5.1 Class Signature**  
```powershell
[NoRunspaceAffinity()]
Class DataHash
```
- **NoRunspaceAffinity**: Ensures thread safety in multi-runspace environments.  
- **Encapsulation**: Uses a structured class-based approach.  

### **5.2 Properties**  

| **Property** | **Type** | **Accessibility** | **Description** |
|-------------|---------|------------------|----------------|
| `$Hash` | `[string]` | Public | Stores the computed hash value. |
| `$IgnoreFields` | `[HashSet[string]]` | Public | Tracks fields excluded from hashing. |
| `$HashAlgorithm` | `[string]` | Public | Defines the hash algorithm used. |
| `$_visited` | `[HashSet[object]]` | Private | Tracks visited objects for circular reference detection. |

### **5.3 Constructors**  

| **Constructor** | **Parameters** | **Functionality** |
|---------------|--------------|----------------|
| `DataHash()` | None | Initializes the class with default values. |
| `DataHash([Object]$InputObject)` | Object to hash | Computes a SHA-256 hash of the object. |
| `DataHash([Object]$InputObject, [HashSet[string]]$IgnoreFields)` | Object to hash, ignored fields | Computes a SHA-256 hash, excluding specified fields. |
| `DataHash([Object]$InputObject, [HashSet[string]]$IgnoreFields, [string]$HashAlgorithm)` | Object to hash, ignored fields, algorithm | Computes a hash using the specified algorithm. |

## **6. Functional Specification**  

### **6.1 Hash Computation (`Digest`)**  

#### **6.1.1 Method Signature**  
```powershell
[void] Digest([object]$InputObject)
[void] Digest([object]$InputObject, [string]$HashAlgorithm)
```
#### **6.1.2 Behavior**  
- Validates input object.  
- Normalizes data (converts objects, lists, and dictionaries into deterministic representations).  
- Computes the hash using the specified algorithm.  

#### **6.1.3 Input Validation**  
- **Null Check**: Throws an error if `InputObject` is `$null`.  
- **Algorithm Validation**: Ensures `HashAlgorithm` is defined in `DataHashAlgorithmType`.  

### **6.2 Data Normalization**  

To ensure consistency, the class normalizes all input objects before hashing.  

| **Method** | **Functionality** |
|------------|----------------|
| `_normalizeValue` | Converts scalar, dictionary, and enumerable values into a stable format. |
| `_normalizeDict` | Converts dictionaries to ordered structures. |
| `_normalizeList` | Sorts unordered collections for deterministic output. |
| `_normalizeFloat` | Ensures consistent floating-point representation. |

### **6.3 Circular Reference Handling**  

- The class maintains a `HashSet` of visited objects (`$_visited`).  
- Before processing a structure, it checks if the reference exists in `$_visited`.  
- If detected, the value is replaced with `"[CIRCULAR_REF]"` instead of skipping it, ensuring that the hash updates if the value later changes to something other than a self-reference.  

### **6.4 Hash Computation & Serialization**  

#### **6.4.1 BSON Serialization**  
- Uses LiteDB's BSON serialization to transform objects into binary representations.  
- **Method:**  
  ```powershell
  static hidden [void] _serializeToBsonStream([Stream]$Stream, [object]$InputObject)
  ```
- Converts PowerShell objects to BSON documents.  

#### **6.4.2 Streaming Hash Calculation**  
```powershell
static hidden [string] _computeHash_Streaming([System.IO.Stream]$Stream, [string]$Algorithm)
```
- Uses **streaming hashing** to process large objects efficiently.  
- Reads input in **4KB chunks** for performance optimization.  
- Implements incremental hashing via `.TransformBlock()` and `.TransformFinalBlock()`.  

## **7. Object Comparison Operations**  

### **7.1 Equality & Inequality Operators**  

| **Operator** | **Comparison** | **Returns** |
|-------------|--------------|------------|
| `op_Equality([DataHash], [DataHash])` | Hash values of two `DataHash` objects | Boolean |
| `op_Equality([DataHash], [string])` | `DataHash` object vs. string hash | Boolean |
| `op_Inequality([DataHash], [DataHash])` | Hash values differ | Boolean |
| `op_Inequality([DataHash], [string])` | Hash differs from string | Boolean |

### **7.2 String Representation**  
```powershell
[string] ToString()
```
- Returns the computed hash string.  

### **7.3 Hash Code Generation**  
```powershell
[int] GetHashCode()
```
- Computes a hash code based on the stored `$Hash` value.  

## **8. Security Considerations**  

- **MD5 and SHA-1 are weak** and should be avoided for cryptographic applications.  
- **SHA-256, SHA-384, and SHA-512** provide strong security guarantees.  
- **Circular reference detection ensures hash updates if the object changes**.  

## **9. Performance Considerations**  

- **Streaming hash computation minimizes memory usage** for large objects.  
- **Sorting unordered collections ensures deterministic output** while incurring minimal overhead.  
- **BSON serialization provides efficient object representation** for hashing.  

## **10. Conclusion**  

The `DataHash` class offers a **robust**, **deterministic**, and **configurable** hashing mechanism suitable for **structured object hashing**. It adheres to **ISO cryptographic standards**, incorporates **performance optimizations**, and **ensures stability across executions**.