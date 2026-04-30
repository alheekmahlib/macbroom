import SwiftUI

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case arabic = "ar"
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .arabic: return "العربية"
        }
    }
    
    var layoutDirection: LayoutDirection {
        switch self {
        case .english: return .leftToRight
        case .arabic: return .rightToLeft
        }
    }
}

// MARK: - Localization
enum L {
    // MARK: - Tab Names
    static func home(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Home"
        case .arabic: return "الرئيسية"
        }
    }
    
    static func smartClean(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Smart Clean"
        case .arabic: return "تنظيف ذكي"
        }
    }
    
    static func apps(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Apps"
        case .arabic: return "التطبيقات"
        }
    }
    
    static func monitor(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Monitor"
        case .arabic: return "المراقب"
        }
    }
    
    static func settings(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Settings"
        case .arabic: return "الإعدادات"
        }
    }
    
    // MARK: - Home
    static func healthScore(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Health Score"
        case .arabic: return "معدل الصحة"
        }
    }
    
    static func yourMacHealth(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Your Mac Health"
        case .arabic: return "صحة جهازك"
        }
    }
    
    static func greatShape(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Your Mac is in great shape! ✨"
        case .arabic: return "جهازك بحالة ممتازة! ✨"
        }
    }
    
    static func cleaningRecommended(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Some cleaning recommended"
        case .arabic: return "يُنصح ببعض التنظيف"
        }
    }
    
    static func needsAttention(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Your Mac needs attention"
        case .arabic: return "جهازك يحتاج اهتمام"
        }
    }
    
    static func critical(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Critical — clean now!"
        case .arabic: return "حرج — نظّف الآن!"
        }
    }
    
    static func quickActions(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Quick Actions"
        case .arabic: return "إجراءات سريعة"
        }
    }
    
    static func scanCleanJunk(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Scan & clean junk files"
        case .arabic: return "فحص وتنظيف الملفات"
        }
    }
    
    static func removeApps(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Remove apps completely"
        case .arabic: return "إزالة التطبيقات بالكامل"
        }
    }
    
    static func realtimePerf(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Real-time performance"
        case .arabic: return "الأداء في الوقت الحقيقي"
        }
    }
    
    // MARK: - Smart Clean
    static func scanAndRemove(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Scan and remove junk files safely"
        case .arabic: return "فحص وإزالة الملفات غير الضرورية بأمان"
        }
    }
    
    static func scanNow(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Scan Now"
        case .arabic: return "فحص الآن"
        }
    }
    
    static func includeBrowserData(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Include Browser Data"
        case .arabic: return "تضمين بيانات المتصفح"
        }
    }
    
    static func readyToClean(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Ready to Clean"
        case .arabic: return "جاهز للتنظيف"
        }
    }
    
    static func readyToCleanDesc(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Scan your Mac to find junk files, caches,\nand unnecessary data that can be safely removed."
        case .arabic: return "افحص جهازك لإيجاد الملفات غير الضرورية وذاكرة التخزين المؤقت\nوالبيانات التي يمكن إزالتها بأمان."
        }
    }
    
    static func scanning(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Scanning..."
        case .arabic: return "جاري الفحص..."
        }
    }
    
    static func scanningSub(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Looking for files to clean..."
        case .arabic: return "البحث عن ملفات للتنظيف..."
        }
    }
    
    static func safeToDelete(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Safe to Delete"
        case .arabic: return "آمن الحذف"
        }
    }
    
    static func safeToDeleteSub(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Can be removed without any issues"
        case .arabic: return "يمكن إزالته بدون أي مشاكل"
        }
    }
    
    static func useCaution(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Use Caution"
        case .arabic: return "انتبه"
        }
    }
    
    static func useCautionSub(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "May reset app preferences or data"
        case .arabic: return "قد يعيد ضبط إعدادات التطبيق"
        }
    }
    
    static func protected(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Protected"
        case .arabic: return "محمي"
        }
    }
    
    static func protectedSub(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Required by system — cannot be deleted"
        case .arabic: return "مطلوب من النظام — لا يمكن حذفه"
        }
    }
    
    static func selectAllSafe(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Select All Safe"
        case .arabic: return "اختر كل الآمن"
        }
    }
    
    static func deselectAll(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Deselect All"
        case .arabic: return "إلغاء الكل"
        }
    }
    
    static func cleanSelected(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Clean Selected"
        case .arabic: return "تنظيف المحدد"
        }
    }
    
    static func cleaning(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Cleaning..."
        case .arabic: return "جاري التنظيف..."
        }
    }
    
    static func filesCleaned(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "files cleaned"
        case .arabic: return "ملفات تم تنظيفها"
        }
    }
    
    static func allClean(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "All Clean! ✨"
        case .arabic: return "نظيف تماماً! ✨"
        }
    }
    
    static func freedUp(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Freed up"
        case .arabic: return "تم تحرير"
        }
    }
    
    static func ofSpace(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "of space"
        case .arabic: return "من المساحة"
        }
    }
    
    static func runningSmoother(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Your Mac is running smoother now."
        case .arabic: return "جهازك يعمل بسلاسة أكبر الآن."
        }
    }
    
    static func scanAgain(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Scan Again"
        case .arabic: return "فحص مرة أخرى"
        }
    }
    
    // MARK: - Categories
    static func systemCache(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "System Cache"
        case .arabic: return "ذاكرة النظام المؤقتة"
        }
    }
    
    static func appCache(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "App Cache"
        case .arabic: return "ذاكرة التطبيقات المؤقتة"
        }
    }
    
    static func logFiles(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Log Files"
        case .arabic: return "ملفات السجل"
        }
    }
    
    static func xcodeDerived(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Xcode Derived Data"
        case .arabic: return "بيانات Xcode المشتقة"
        }
    }
    
    static func browserData(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Browser Data"
        case .arabic: return "بيانات المتصفح"
        }
    }
    
    static func trashItems(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Trash Items"
        case .arabic: return "عناصر سلة المهملات"
        }
    }
    
    // MARK: - App Uninstaller
    static func appUninstaller(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "App Uninstaller"
        case .arabic: return "إزالة التطبيقات"
        }
    }
    
    static func removeAppsSafely(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Remove apps or clean their data safely"
        case .arabic: return "إزالة التطبيقات أو تنظيف بياناتها بأمان"
        }
    }
    
    static func uninstallApp(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Uninstall App"
        case .arabic: return "إزالة التطبيق"
        }
    }
    
    static func deleteSelected(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Delete Selected"
        case .arabic: return "حذف المحدد"
        }
    }
    
    // MARK: - System Monitor
    static func systemMonitor(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "System Monitor"
        case .arabic: return "مراقب النظام"
        }
    }
    
    static func realtimePerformance(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Real-time system performance"
        case .arabic: return "أداء النظام في الوقت الحقيقي"
        }
    }
    
    static func topProcesses(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Top Processes"
        case .arabic: return "أعلى العمليات"
        }
    }
    
    static func network(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Network"
        case .arabic: return "الشبكة"
        }
    }
    
    // MARK: - Settings
    static func settingsGeneral(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "General"
        case .arabic: return "عام"
        }
    }
    
    static func launchAtLogin(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Launch at Login"
        case .arabic: return "تشغيل عند تسجيل الدخول"
        }
    }
    
    static func showMenuBar(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Show in Menu Bar"
        case .arabic: return "إظهار في شريط القوائم"
        }
    }
    
    static func language(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Language"
        case .arabic: return "اللغة"
        }
    }
    
    static func cleaningSection(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Cleaning"
        case .arabic: return "التنظيف"
        }
    }
    
    static func safety(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Safety"
        case .arabic: return "الأمان"
        }
    }
    
    static func about(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "About"
        case .arabic: return "حول"
        }
    }
    
    static func confirmBeforeDelete(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Confirm before deleting"
        case .arabic: return "تأكيد قبل الحذف"
        }
    }
    
    static func keepBackup(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Keep backup for 30 days"
        case .arabic: return "الاحتفاظ بنسخة احتياطية لمدة 30 يوم"
        }
    }
    
    // MARK: - Menu Bar
    static func openMacBroom(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Open MacBroom"
        case .arabic: return "فتح MacBroom"
        }
    }
    
    static func quickClean(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Quick Clean"
        case .arabic: return "تنظيف سريع"
        }
    }
    
    static func quitMacBroom(_ lang: AppLanguage = .english) -> String {
        switch lang {
        case .english: return "Quit MacBroom"
        case .arabic: return "إنهاء MacBroom"
        }
    }
}
