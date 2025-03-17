# Get-DataHash

# **📌 Get-DataHash and [DataHash]: PowerShell Object Thumbprinting**  

`DataHash` is a **PowerShell-native hashing utility** designed for **consistent, unique thumbprinting of objects**. It ensures reliable **object identity, integrity checks, and caching** across PowerShell sessions. It supports **nested structures, field exclusions, and configurable hash algorithms** while handling **lists, dictionaries, and circular references**.  

✅ **Works on:** Windows, macOS, Linux (x86, ARM)  
⚠ **PowerShell 5.1 Compatibility:** Not yet! 
🔒 **Default Hash Algorithm:** SHA-256 (supports SHA-512, SHA-384, SHA-1, MD5)  

🚀 **Designed for:**  
- Object **fingerprinting & deduplication**  
- **Data integrity verification**  
- **Efficient caching** with stable hashes  
- **Audit logging & forensic analysis**  

**Cross-platform note:** Hashes are **consistent on the same machine** and should be stable across **modern .NET-supported platforms (Windows/macOS/Linux)**. However, **big-endian architectures** may produce different results.