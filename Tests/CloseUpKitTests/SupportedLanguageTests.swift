import Testing

@testable import CloseUpKit

@Suite("SupportedLanguage")
struct SupportedLanguageTests {
    @Test("ships exactly the nine required languages")
    func shipsNineLanguages() {
        #expect(SupportedLanguage.allCases.count == 9)
        let codes = Set(SupportedLanguage.allCases.map(\.rawValue))
        #expect(codes == ["en", "zh-Hans", "zh-Hant", "ja", "fr", "de", "es", "pt", "ru"])
    }

    @Test("resolves BCP-47 codes to the right language")
    func resolvesPreferredLanguages() {
        #expect(SupportedLanguage.resolve(preferredLanguages: ["ja-JP"]) == .japanese)
        #expect(SupportedLanguage.resolve(preferredLanguages: ["fr-CA"]) == .french)
        #expect(SupportedLanguage.resolve(preferredLanguages: ["pt-BR"]) == .portuguese)
        // Unknown languages fall back to English.
        #expect(SupportedLanguage.resolve(preferredLanguages: ["ko-KR"]) == .english)
        // First recognized wins.
        #expect(SupportedLanguage.resolve(preferredLanguages: ["ko", "de-DE"]) == .german)
    }

    @Test("infers Chinese script from region when unscripted")
    func inferChineseScript() {
        #expect(SupportedLanguage.resolve(preferredLanguages: ["zh-TW"]) == .traditionalChinese)
        #expect(SupportedLanguage.resolve(preferredLanguages: ["zh-HK"]) == .traditionalChinese)
        #expect(SupportedLanguage.resolve(preferredLanguages: ["zh-CN"]) == .simplifiedChinese)
        #expect(SupportedLanguage.resolve(preferredLanguages: ["zh"]) == .simplifiedChinese)
        #expect(SupportedLanguage.resolve(preferredLanguages: ["zh-Hant"]) == .traditionalChinese)
    }

    @Test("matches regional variants to a bundle's available localizations")
    func preferredLocalization() {
        #expect(SupportedLanguage.traditionalChinese.preferredLocalization(from: ["en", "zh-TW"]) == "zh-TW")
        #expect(SupportedLanguage.portuguese.preferredLocalization(from: ["en", "pt-BR"]) == "pt-BR")
        #expect(SupportedLanguage.japanese.preferredLocalization(from: ["en", "ja"]) == "ja")
        #expect(SupportedLanguage.german.preferredLocalization(from: ["en", "fr"]) == nil)
    }
}
