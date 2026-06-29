# ScoutManager MVP‑1 — Plan 1 : Fondation (Design System + Shell)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mettre en place le Design System SGDF centralisé et le shell de navigation
(login → TabView 5 onglets) pour ScoutManager, le tout compilable et partiellement
couvert par des tests unitaires.

**Architecture:** App iOS native SwiftUI, MVVM. On fait évoluer le projet existant
`ScoutInventory` en `ScoutManager` *en place*. Ce plan ne touche ni Supabase ni les
données : il pose les couleurs, le thème, les composants réutilisables et la navigation.
Les couleurs sont la **seule** source de couleur de l'app.

**Tech Stack:** Swift 5, SwiftUI, iOS 17+, XCTest. Xcode 16+ (projet `ScoutInventory.xcodeproj`).

## Global Constraints

- **iOS 17+**, SwiftUI uniquement. Pas de Flutter / React Native / Capacitor / WebView.
- **Aucune couleur hors `ScoutManager/DesignSystem/`.** Interdit dans toute vue :
  `Color.blue`, `Color.red`, `Color.orange`, `Color(red:…)`, ou un hex en dur.
  L'extension `Color(hex:)` est `fileprivate`/interne au DesignSystem.
- **Palette SGDF exacte** : primaryBlue `#003a5d`, orange `#ff8300`, lightBlue `#0077b3`,
  red `#d03f15`, green `#007254`, lightGreen `#65bc99`, violet `#6e74aa`.
- **Neutres** : background `#F7F8FA`, surface `#FFFFFF`, border `#E3E6EB`,
  textPrimary `#003a5d`, textSecondary `#5B6B7A`.
- `#003a5d` doit rester **dominant** (NavBar, TabBar tint, titres, boutons principaux,
  onglet actif).
- Tout nouveau fichier source vit sous `ScoutManager/` (groupe synchronisé). Le code
  `ScoutInventory/` existant n'est PAS supprimé dans ce plan (retrait progressif plus tard),
  mais le `@main` bascule sur `ScoutManager`.
- Bundle id cible : `com.scout.manager`. Scheme/target affichés : `ScoutManager`.

---

## File Structure

Créés par ce plan :

```
ScoutManager/
  App/
    ScoutManagerApp.swift          @main, injecte l'environnement, applique le thème
    RootView.swift                 login (réutilise l'auth existante) ↔ MainTabView
    MainTabView.swift              TabView 5 onglets
  DesignSystem/
    Color+Hex.swift                extension fileprivate Color(hex:) — interne au DS
    SGDFColors.swift               7 couleurs chartées + 5 neutres
    SGDFTheme.swift                typo, espacements, rayons, tint global
    StatusColorMapper.swift        ItemStatus → Color
  Models/
    ItemStatus.swift               enum statut (requis par le mapper)
  Components/
    SGDFButton.swift
    SGDFCard.swift
    SGDFBadge.swift
    SGDFTextField.swift
    EmptyStateView.swift
    LoadingView.swift
  Views/
    Placeholder/ComingSoonView.swift   écran « Bientôt » natif (Intendance, Camp)
ScoutManagerTests/
    SGDFColorsTests.swift
    StatusColorMapperTests.swift
    ColorHexTests.swift
```

Modifiés :
- `ScoutInventory.xcodeproj/project.pbxproj` — ajout target de test `ScoutManagerTests`,
  renommage scheme/affichage en ScoutManager, bundle id, basculement du `@main`.
- `ScoutInventory/ScoutInventoryApp.swift` — retrait de l'attribut `@main` (un seul `@main`).

> Note plateforme : les vues SwiftUI ne sont pas unit‑testables simplement. On applique
> le TDD à la **logique pure** (parsing hex, valeurs de palette, mapping de statut) via
> XCTest, et on vérifie les vues par **compilation + exécution**.

---

## Task 1 : Cible de tests + extension `Color(hex:)`

**Files:**
- Modify: `ScoutInventory.xcodeproj/project.pbxproj` (ajout target `ScoutManagerTests`)
- Create: `ScoutManager/DesignSystem/Color+Hex.swift`
- Test: `ScoutManagerTests/ColorHexTests.swift`

**Interfaces:**
- Produces: `extension Color { init(hex: String) }` — **interne au module** (pas `public`),
  parse `"#RRGGBB"` et `"RRGGBB"`. Expose pour les tests une fonction pure testable
  `SGDFHex.rgb(from:) -> (r: Double, g: Double, b: Double)?`.

- [ ] **Step 1 : Ajouter la cible de tests `ScoutManagerTests`**

Le projet n'a aucune cible de test. Ajouter une **Unit Testing Bundle** nommée
`ScoutManagerTests`, host application = la target principale. En agent, éditer
`project.pbxproj` ; sinon, dans Xcode : File ▸ New ▸ Target ▸ Unit Testing Bundle ▸
« ScoutManagerTests », « Target to be Tested » = l'app.

Vérifier que la cible compile à vide :

Run: `xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutManager -destination 'platform=iOS Simulator,name=iPhone 16' build-for-testing 2>&1 | tail -3`
Expected: `** TEST BUILD SUCCEEDED **` (cible vide, aucun test encore).

- [ ] **Step 2 : Écrire le test qui échoue**

`ScoutManagerTests/ColorHexTests.swift` :

```swift
import XCTest
@testable import ScoutManager

final class ColorHexTests: XCTestCase {
    func test_parsesSixDigitHexWithHash() {
        let rgb = SGDFHex.rgb(from: "#003a5d")
        XCTAssertNotNil(rgb)
        XCTAssertEqual(rgb!.r, 0x00 / 255.0, accuracy: 0.001)
        XCTAssertEqual(rgb!.g, 0x3a / 255.0, accuracy: 0.001)
        XCTAssertEqual(rgb!.b, 0x5d / 255.0, accuracy: 0.001)
    }

    func test_parsesWithoutHash() {
        XCTAssertNotNil(SGDFHex.rgb(from: "ff8300"))
    }

    func test_returnsNilOnInvalid() {
        XCTAssertNil(SGDFHex.rgb(from: "xyz"))
        XCTAssertNil(SGDFHex.rgb(from: "#12"))
    }
}
```

- [ ] **Step 3 : Lancer le test, vérifier qu'il échoue**

Run: `xcodebuild test -project ScoutInventory.xcodeproj -scheme ScoutManager -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ScoutManagerTests/ColorHexTests 2>&1 | tail -5`
Expected: échec de compilation `cannot find 'SGDFHex' in scope`.

- [ ] **Step 4 : Implémenter le minimum**

`ScoutManager/DesignSystem/Color+Hex.swift` :

```swift
import SwiftUI

/// Parsing hex centralisé — réservé au Design System.
/// Aucune vue ne doit appeler ceci directement : les couleurs passent par SGDFColors.
enum SGDFHex {
    /// Convertit "#RRGGBB" ou "RRGGBB" en composantes 0...1. nil si invalide.
    static func rgb(from hex: String) -> (r: Double, g: Double, b: Double)? {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        return (
            r: Double((value >> 16) & 0xff) / 255.0,
            g: Double((value >> 8) & 0xff) / 255.0,
            b: Double(value & 0xff) / 255.0
        )
    }
}

extension Color {
    /// Initialise une couleur depuis un hex SGDF. Fallback magenta visible si invalide
    /// (signale une erreur de charte en développement).
    init(hex: String) {
        guard let c = SGDFHex.rgb(from: hex) else {
            self = Color(red: 1, green: 0, blue: 1)
            return
        }
        self = Color(red: c.r, green: c.g, blue: c.b)
    }
}
```

- [ ] **Step 5 : Lancer les tests, vérifier qu'ils passent**

Run: `xcodebuild test -project ScoutInventory.xcodeproj -scheme ScoutManager -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ScoutManagerTests/ColorHexTests 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6 : Commit**

```bash
git add ScoutInventory.xcodeproj/project.pbxproj ScoutManager/DesignSystem/Color+Hex.swift ScoutManagerTests/ColorHexTests.swift
git commit -m "feat(ds): Color(hex:) parsing + ScoutManagerTests target"
```

---

## Task 2 : `SGDFColors` (palette chartée + neutres)

**Files:**
- Create: `ScoutManager/DesignSystem/SGDFColors.swift`
- Test: `ScoutManagerTests/SGDFColorsTests.swift`

**Interfaces:**
- Consumes: `SGDFHex.rgb(from:)`.
- Produces: `enum SGDFColors` avec `static let` `Color` : `primaryBlue, orange, lightBlue,
  red, green, lightGreen, violet, background, surface, border, textPrimary, textSecondary`.
  Et `static let hexValues: [String: String]` (nom → hex) pour les tests.

- [ ] **Step 1 : Écrire le test qui échoue**

`ScoutManagerTests/SGDFColorsTests.swift` :

```swift
import XCTest
@testable import ScoutManager

final class SGDFColorsTests: XCTestCase {
    func test_chartedHexValuesAreExact() {
        XCTAssertEqual(SGDFColors.hexValues["primaryBlue"], "#003a5d")
        XCTAssertEqual(SGDFColors.hexValues["orange"], "#ff8300")
        XCTAssertEqual(SGDFColors.hexValues["lightBlue"], "#0077b3")
        XCTAssertEqual(SGDFColors.hexValues["red"], "#d03f15")
        XCTAssertEqual(SGDFColors.hexValues["green"], "#007254")
        XCTAssertEqual(SGDFColors.hexValues["lightGreen"], "#65bc99")
        XCTAssertEqual(SGDFColors.hexValues["violet"], "#6e74aa")
    }

    func test_neutralHexValuesAreExact() {
        XCTAssertEqual(SGDFColors.hexValues["background"], "#F7F8FA")
        XCTAssertEqual(SGDFColors.hexValues["surface"], "#FFFFFF")
        XCTAssertEqual(SGDFColors.hexValues["border"], "#E3E6EB")
        XCTAssertEqual(SGDFColors.hexValues["textPrimary"], "#003a5d")
        XCTAssertEqual(SGDFColors.hexValues["textSecondary"], "#5B6B7A")
    }

    func test_textPrimaryIsInstitutionalBlue() {
        XCTAssertEqual(SGDFColors.hexValues["textPrimary"], SGDFColors.hexValues["primaryBlue"])
    }
}
```

- [ ] **Step 2 : Lancer le test, vérifier qu'il échoue**

Run: `xcodebuild test -project ScoutInventory.xcodeproj -scheme ScoutManager -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ScoutManagerTests/SGDFColorsTests 2>&1 | tail -5`
Expected: `cannot find 'SGDFColors' in scope`.

- [ ] **Step 3 : Implémenter**

`ScoutManager/DesignSystem/SGDFColors.swift` :

```swift
import SwiftUI

/// Source UNIQUE de couleur de l'app. Aucune vue n'écrit un hex ou une Color système.
/// Charte SGDF — ne jamais ajouter une couleur forte hors palette.
enum SGDFColors {
    // Couleur principale
    static let primaryBlue = Color(hex: "#003a5d")

    // Secondaires
    static let orange      = Color(hex: "#ff8300")
    static let lightBlue   = Color(hex: "#0077b3")
    static let red         = Color(hex: "#d03f15")
    static let green       = Color(hex: "#007254")
    static let lightGreen  = Color(hex: "#65bc99")
    static let violet      = Color(hex: "#6e74aa")

    // Neutres interface
    static let background    = Color(hex: "#F7F8FA")
    static let surface       = Color(hex: "#FFFFFF")
    static let border        = Color(hex: "#E3E6EB")
    static let textPrimary   = Color(hex: "#003a5d")
    static let textSecondary = Color(hex: "#5B6B7A")

    /// Table nom → hex, source de vérité vérifiée par les tests.
    static let hexValues: [String: String] = [
        "primaryBlue": "#003a5d", "orange": "#ff8300", "lightBlue": "#0077b3",
        "red": "#d03f15", "green": "#007254", "lightGreen": "#65bc99", "violet": "#6e74aa",
        "background": "#F7F8FA", "surface": "#FFFFFF", "border": "#E3E6EB",
        "textPrimary": "#003a5d", "textSecondary": "#5B6B7A"
    ]
}
```

- [ ] **Step 4 : Lancer les tests, vérifier qu'ils passent**

Run: `xcodebuild test -project ScoutInventory.xcodeproj -scheme ScoutManager -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ScoutManagerTests/SGDFColorsTests 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5 : Commit**

```bash
git add ScoutManager/DesignSystem/SGDFColors.swift ScoutManagerTests/SGDFColorsTests.swift
git commit -m "feat(ds): SGDFColors charted palette + neutrals"
```

---

## Task 3 : `ItemStatus` + `StatusColorMapper`

**Files:**
- Create: `ScoutManager/Models/ItemStatus.swift`
- Create: `ScoutManager/DesignSystem/StatusColorMapper.swift`
- Test: `ScoutManagerTests/StatusColorMapperTests.swift`

**Interfaces:**
- Consumes: `SGDFColors`.
- Produces:
  - `enum ItemStatus: String, Codable, CaseIterable` cases `disponible, reserve, sorti,
    aVerifier, aReparer, indisponible, perdu, archive` avec rawValues DB
    (`"disponible","reserve","sorti","a_verifier","a_reparer","indisponible","perdu","archive"`)
    et `var label: String` (libellés FR affichables).
  - `enum StatusColorMapper { static func color(for: ItemStatus) -> Color
    static func colorName(for: ItemStatus) -> String }` (colorName = nom de token pour test).

- [ ] **Step 1 : Écrire le test qui échoue**

`ScoutManagerTests/StatusColorMapperTests.swift` :

```swift
import XCTest
@testable import ScoutManager

final class StatusColorMapperTests: XCTestCase {
    func test_mappingMatchesCharter() {
        XCTAssertEqual(StatusColorMapper.colorName(for: .disponible), "lightGreen")
        XCTAssertEqual(StatusColorMapper.colorName(for: .reserve), "violet")
        XCTAssertEqual(StatusColorMapper.colorName(for: .sorti), "orange")
        XCTAssertEqual(StatusColorMapper.colorName(for: .aVerifier), "orange")
        XCTAssertEqual(StatusColorMapper.colorName(for: .aReparer), "red")
        XCTAssertEqual(StatusColorMapper.colorName(for: .indisponible), "red")
        XCTAssertEqual(StatusColorMapper.colorName(for: .perdu), "red")
        XCTAssertEqual(StatusColorMapper.colorName(for: .archive), "textSecondary")
    }

    func test_everyStatusHasAMapping() {
        for status in ItemStatus.allCases {
            XCTAssertFalse(StatusColorMapper.colorName(for: status).isEmpty)
        }
    }

    func test_rawValuesAreStableForDB() {
        XCTAssertEqual(ItemStatus.aVerifier.rawValue, "a_verifier")
        XCTAssertEqual(ItemStatus.aReparer.rawValue, "a_reparer")
    }
}
```

- [ ] **Step 2 : Lancer le test, vérifier qu'il échoue**

Run: `xcodebuild test -project ScoutInventory.xcodeproj -scheme ScoutManager -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ScoutManagerTests/StatusColorMapperTests 2>&1 | tail -5`
Expected: `cannot find 'ItemStatus' in scope`.

- [ ] **Step 3 : Implémenter `ItemStatus`**

`ScoutManager/Models/ItemStatus.swift` :

```swift
import Foundation

/// Statut d'un matériel. rawValue = valeur stockée en base (snake_case).
enum ItemStatus: String, Codable, CaseIterable {
    case disponible   = "disponible"
    case reserve      = "reserve"
    case sorti        = "sorti"
    case aVerifier    = "a_verifier"
    case aReparer     = "a_reparer"
    case indisponible = "indisponible"
    case perdu        = "perdu"
    case archive      = "archive"

    var label: String {
        switch self {
        case .disponible:   return "Disponible"
        case .reserve:      return "Réservé"
        case .sorti:        return "Sorti"
        case .aVerifier:    return "À vérifier"
        case .aReparer:     return "À réparer"
        case .indisponible: return "Indisponible"
        case .perdu:        return "Perdu"
        case .archive:      return "Archivé"
        }
    }
}
```

- [ ] **Step 4 : Implémenter `StatusColorMapper`**

`ScoutManager/DesignSystem/StatusColorMapper.swift` :

```swift
import SwiftUI

/// Mapping statut → couleur SGDF. Source unique pour badges/cartes/indicateurs.
/// Ne jamais colorer un statut à la main dans une vue.
enum StatusColorMapper {
    static func color(for status: ItemStatus) -> Color {
        switch status {
        case .disponible:   return SGDFColors.lightGreen
        case .reserve:      return SGDFColors.violet
        case .sorti:        return SGDFColors.orange
        case .aVerifier:    return SGDFColors.orange
        case .aReparer:     return SGDFColors.red
        case .indisponible: return SGDFColors.red
        case .perdu:        return SGDFColors.red
        case .archive:      return SGDFColors.textSecondary
        }
    }

    /// Nom de token (pour vérification de charte par les tests).
    static func colorName(for status: ItemStatus) -> String {
        switch status {
        case .disponible:                         return "lightGreen"
        case .reserve:                            return "violet"
        case .sorti, .aVerifier:                  return "orange"
        case .aReparer, .indisponible, .perdu:    return "red"
        case .archive:                            return "textSecondary"
        }
    }
}
```

- [ ] **Step 5 : Lancer les tests, vérifier qu'ils passent**

Run: `xcodebuild test -project ScoutInventory.xcodeproj -scheme ScoutManager -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ScoutManagerTests/StatusColorMapperTests 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6 : Commit**

```bash
git add ScoutManager/Models/ItemStatus.swift ScoutManager/DesignSystem/StatusColorMapper.swift ScoutManagerTests/StatusColorMapperTests.swift
git commit -m "feat(ds): ItemStatus enum + StatusColorMapper (charter mapping)"
```

---

## Task 4 : `SGDFTheme` (typo, espacements, rayons, tint)

**Files:**
- Create: `ScoutManager/DesignSystem/SGDFTheme.swift`

**Interfaces:**
- Consumes: `SGDFColors`.
- Produces: `enum SGDFTheme` avec `enum Spacing { static let xs/sm/md/lg/xl: CGFloat }`,
  `enum Radius { static let card/button/badge: CGFloat }`,
  `enum FontStyle { static func screenTitle()/sectionTitle()/body()/caption() -> Font }`,
  `static let tint = SGDFColors.primaryBlue`. Pas de test unitaire (constantes de style) —
  vérifié par compilation.

- [ ] **Step 1 : Implémenter**

`ScoutManager/DesignSystem/SGDFTheme.swift` :

```swift
import SwiftUI

/// Constantes de style SGDF : espacements, rayons, typographies, tint global.
/// Usage terrain : boutons grands, lisibilité forte, beaucoup de blanc.
enum SGDFTheme {
    static let tint = SGDFColors.primaryBlue

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 16
        static let button: CGFloat = 12
        static let badge: CGFloat = 8
    }

    /// Hauteur mini des boutons tactiles (usage gants/terrain).
    static let buttonMinHeight: CGFloat = 52

    enum FontStyle {
        static func screenTitle() -> Font { .system(.largeTitle, design: .rounded).weight(.bold) }
        static func sectionTitle() -> Font { .system(.title3, design: .rounded).weight(.semibold) }
        static func body() -> Font { .system(.body) }
        static func caption() -> Font { .system(.caption) }
    }
}
```

- [ ] **Step 2 : Vérifier la compilation**

Run: `xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutManager -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3 : Commit**

```bash
git add ScoutManager/DesignSystem/SGDFTheme.swift
git commit -m "feat(ds): SGDFTheme spacing/radius/typography/tint"
```

---

## Task 5 : Composants réutilisables

**Files:**
- Create: `ScoutManager/Components/SGDFButton.swift`
- Create: `ScoutManager/Components/SGDFCard.swift`
- Create: `ScoutManager/Components/SGDFBadge.swift`
- Create: `ScoutManager/Components/SGDFTextField.swift`
- Create: `ScoutManager/Components/EmptyStateView.swift`
- Create: `ScoutManager/Components/LoadingView.swift`

**Interfaces:**
- Consumes: `SGDFColors`, `SGDFTheme`, `ItemStatus`, `StatusColorMapper`.
- Produces:
  - `enum SGDFButtonStyleKind { case primary, quickAction, secondary }`
  - `struct SGDFButton: View` — `init(_ title: String, kind: SGDFButtonStyleKind = .primary,
    systemImage: String? = nil, action: @escaping () -> Void)`
  - `struct SGDFCard<Content: View>: View` — `init(@ViewBuilder content: () -> Content)`
  - `struct SGDFBadge: View` — `init(status: ItemStatus)`
  - `struct SGDFTextField: View` — `init(_ placeholder: String, text: Binding<String>,
    systemImage: String? = nil)`
  - `struct EmptyStateView: View` — `init(systemImage: String, title: String, message: String)`
  - `struct LoadingView: View` — `init(_ message: String = "Chargement…")`

- [ ] **Step 1 : `SGDFButton`**

```swift
import SwiftUI

enum SGDFButtonStyleKind { case primary, quickAction, secondary }

/// Bouton SGDF. primary = bleu, quickAction = orange (actions rapides), secondary = contour.
struct SGDFButton: View {
    let title: String
    var kind: SGDFButtonStyleKind = .primary
    var systemImage: String? = nil
    let action: () -> Void

    init(_ title: String, kind: SGDFButtonStyleKind = .primary,
         systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title; self.kind = kind; self.systemImage = systemImage; self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: SGDFTheme.Spacing.sm) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).font(.system(.body, design: .rounded).weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: SGDFTheme.buttonMinHeight)
            .foregroundStyle(foreground)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: SGDFTheme.Radius.button)
                    .stroke(SGDFColors.primaryBlue, lineWidth: kind == .secondary ? 1.5 : 0)
            )
            .clipShape(RoundedRectangle(cornerRadius: SGDFTheme.Radius.button))
        }
    }

    private var background: Color {
        switch kind {
        case .primary:     return SGDFColors.primaryBlue
        case .quickAction: return SGDFColors.orange
        case .secondary:   return SGDFColors.surface
        }
    }
    private var foreground: Color {
        switch kind {
        case .primary, .quickAction: return .white
        case .secondary:             return SGDFColors.primaryBlue
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        SGDFButton("Ajouter matériel", kind: .quickAction, systemImage: "plus") {}
        SGDFButton("Scanner", kind: .primary, systemImage: "qrcode.viewfinder") {}
        SGDFButton("Annuler", kind: .secondary) {}
    }.padding().background(SGDFColors.background)
}
```

- [ ] **Step 2 : `SGDFCard`**

```swift
import SwiftUI

/// Carte arrondie : surface blanche, bordure très claire, coins arrondis.
struct SGDFCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: SGDFTheme.Spacing.sm, content: content)
            .padding(SGDFTheme.Spacing.md)
            .background(SGDFColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: SGDFTheme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: SGDFTheme.Radius.card)
                    .stroke(SGDFColors.border, lineWidth: 1)
            )
    }
}
```

- [ ] **Step 3 : `SGDFBadge`**

```swift
import SwiftUI

/// Badge de statut. Couleur issue exclusivement de StatusColorMapper.
struct SGDFBadge: View {
    let status: ItemStatus
    var body: some View {
        Text(status.label)
            .font(.system(.caption, design: .rounded).weight(.semibold))
            .padding(.horizontal, SGDFTheme.Spacing.sm)
            .padding(.vertical, SGDFTheme.Spacing.xs)
            .foregroundStyle(.white)
            .background(StatusColorMapper.color(for: status))
            .clipShape(RoundedRectangle(cornerRadius: SGDFTheme.Radius.badge))
    }
}

#Preview {
    VStack(spacing: 8) {
        ForEach(ItemStatus.allCases, id: \.self) { SGDFBadge(status: $0) }
    }.padding().background(SGDFColors.background)
}
```

- [ ] **Step 4 : `SGDFTextField`**

```swift
import SwiftUI

struct SGDFTextField: View {
    let placeholder: String
    @Binding var text: String
    var systemImage: String? = nil

    init(_ placeholder: String, text: Binding<String>, systemImage: String? = nil) {
        self.placeholder = placeholder; self._text = text; self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: SGDFTheme.Spacing.sm) {
            if let systemImage {
                Image(systemName: systemImage).foregroundStyle(SGDFColors.textSecondary)
            }
            TextField(placeholder, text: $text)
                .foregroundStyle(SGDFColors.textPrimary)
        }
        .padding(SGDFTheme.Spacing.md)
        .background(SGDFColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: SGDFTheme.Radius.button))
        .overlay(
            RoundedRectangle(cornerRadius: SGDFTheme.Radius.button)
                .stroke(SGDFColors.border, lineWidth: 1)
        )
    }
}
```

- [ ] **Step 5 : `EmptyStateView` et `LoadingView`**

`EmptyStateView.swift` :

```swift
import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: SGDFTheme.Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(SGDFColors.primaryBlue)
            Text(title)
                .font(SGDFTheme.FontStyle.sectionTitle())
                .foregroundStyle(SGDFColors.textPrimary)
            Text(message)
                .font(SGDFTheme.FontStyle.body())
                .foregroundStyle(SGDFColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(SGDFTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SGDFColors.background)
    }
}
```

`LoadingView.swift` :

```swift
import SwiftUI

struct LoadingView: View {
    let message: String
    init(_ message: String = "Chargement…") { self.message = message }
    var body: some View {
        VStack(spacing: SGDFTheme.Spacing.md) {
            ProgressView().tint(SGDFColors.primaryBlue)
            Text(message)
                .font(SGDFTheme.FontStyle.caption())
                .foregroundStyle(SGDFColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SGDFColors.background)
    }
}
```

- [ ] **Step 6 : Vérifier la compilation**

Run: `xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutManager -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7 : Commit**

```bash
git add ScoutManager/Components/
git commit -m "feat(ds): SGDF components (button, card, badge, textfield, empty, loading)"
```

---

## Task 6 : Shell de navigation (App + RootView + MainTabView)

**Files:**
- Create: `ScoutManager/App/ScoutManagerApp.swift`
- Create: `ScoutManager/App/RootView.swift`
- Create: `ScoutManager/App/MainTabView.swift`
- Create: `ScoutManager/Views/Placeholder/ComingSoonView.swift`
- Modify: `ScoutInventory/ScoutInventoryApp.swift` (retirer `@main`)
- Modify: `ScoutInventory.xcodeproj/project.pbxproj` (bundle id `com.scout.manager`, scheme/affichage `ScoutManager`)

**Interfaces:**
- Consumes: composants + `SGDFColors`/`SGDFTheme`. Réutilise l'`AppState` existant
  (`ScoutInventory/Services/AppState.swift`) pour l'auth ; pas de réécriture de l'auth
  dans ce plan.
- Produces: `@main struct ScoutManagerApp`, `struct RootView`, `struct MainTabView`,
  `struct ComingSoonView`.

- [ ] **Step 1 : `ComingSoonView` (placeholder natif)**

```swift
import SwiftUI

/// Écran « Bientôt » pour les onglets non encore livrés (Intendance, Camp).
struct ComingSoonView: View {
    let title: String
    var body: some View {
        NavigationStack {
            EmptyStateView(systemImage: "hammer.fill",
                           title: "Bientôt disponible",
                           message: "Ce module arrive dans une prochaine étape.")
                .navigationTitle(title)
        }
    }
}
```

- [ ] **Step 2 : `MainTabView` (5 onglets, tint bleu SGDF)**

Pour ce plan, Dashboard/Matériel/Scan affichent un `ComingSoonView` provisoire (remplacés
par les vrais écrans dans les plans suivants). Le tint et la structure sont définitifs.

```swift
import SwiftUI

struct MainTabView: View {
    init() {
        // TabBar et NavBar ancrées sur le bleu SGDF (identité dominante).
        let tint = UIColor(SGDFColors.primaryBlue)
        UITabBar.appearance().tintColor = tint
        UINavigationBar.appearance().tintColor = tint
    }

    var body: some View {
        TabView {
            ComingSoonView(title: "Dashboard")
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }
            ComingSoonView(title: "Matériel")
                .tabItem { Label("Matériel", systemImage: "shippingbox") }
            ComingSoonView(title: "Scan")
                .tabItem { Label("Scan", systemImage: "qrcode.viewfinder") }
            ComingSoonView(title: "Intendance")
                .tabItem { Label("Intendance", systemImage: "fork.knife") }
            ComingSoonView(title: "Camp")
                .tabItem { Label("Camp", systemImage: "tent") }
        }
        .tint(SGDFColors.primaryBlue)
    }
}
```

- [ ] **Step 3 : `RootView` (login ↔ tabs, réutilise l'AppState existant)**

```swift
import SwiftUI

/// Aiguillage racine : non connecté → login existant ; connecté → MainTabView.
struct RootView: View {
    @EnvironmentObject private var appState: AppState
    var body: some View {
        Group {
            if appState.isAuthenticated {
                MainTabView()
            } else {
                LoginView()   // écran existant (ScoutInventory/Views/LoginView.swift)
            }
        }
    }
}
```

- [ ] **Step 4 : `ScoutManagerApp` (nouveau @main)**

```swift
import SwiftUI

@main
struct ScoutManagerApp: App {
    @StateObject private var appState = AppState()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .tint(SGDFColors.primaryBlue)
        }
    }
}
```

- [ ] **Step 5 : Retirer l'ancien `@main`**

Dans `ScoutInventory/ScoutInventoryApp.swift`, supprimer l'attribut `@main` (renommer le
struct en `LegacyScoutInventoryApp` ou retirer le fichier de la cible). Il ne doit rester
qu'**un seul** `@main` dans la cible.

- [ ] **Step 6 : Renommer affichage + bundle id**

Dans `project.pbxproj`, pour Debug et Release : `PRODUCT_BUNDLE_IDENTIFIER = com.scout.manager;`
et `INFOPLIST_KEY_CFBundleDisplayName = ScoutManager;`. Renommer le scheme en `ScoutManager`
(fichier `xcshareddata/xcschemes/ScoutManager.xcscheme` ou via Xcode). La target peut rester
`ScoutInventory` en interne si le renommage de target est trop risqué en agent — l'important
est le bundle id, le display name et le scheme.

- [ ] **Step 7 : Build + run, vérifier**

Run: `xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutManager -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`.

Vérification manuelle (simulateur) : l'app se lance sur le login ; après connexion, la
TabView 5 onglets s'affiche, tint bleu SGDF, onglet actif bleu, écrans « Bientôt ».

- [ ] **Step 8 : Lancer toute la suite de tests**

Run: `xcodebuild test -project ScoutInventory.xcodeproj -scheme ScoutManager -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **` (ColorHex, SGDFColors, StatusColorMapper).

- [ ] **Step 9 : Commit**

```bash
git add ScoutManager/App ScoutManager/Views/Placeholder ScoutInventory/ScoutInventoryApp.swift ScoutInventory.xcodeproj
git commit -m "feat(app): ScoutManager shell — RootView + 5-tab MainTabView, SGDF tint"
```

---

## Self‑Review (couverture de la spec, périmètre Plan 1)

- **Design System complet** (SGDFColors, SGDFTheme, StatusColorMapper, composants) →
  Tasks 1‑5. ✅
- **`Color(hex:)` interne au DS, aucune couleur en dur** → Task 1 + contrainte globale. ✅
- **Mapping de statut charté** → Task 3 (testé). ✅
- **Navigation TabView 5 onglets, bleu dominant** → Task 6. ✅
- **Login conservé** → Task 6 (réutilise `AppState`/`LoginView` existants). ✅
- Hors périmètre de CE plan (couverts par les plans suivants) : Supabase SDK, modèles
  complets, services, Dashboard réel, Matériel, QR. Volontairement non inclus.

Pas de placeholder de plan, types cohérents (`ItemStatus`, `SGDFColors`, `SGDFTheme`,
`StatusColorMapper`, composants) entre les tasks.

---

## Feuille de route — plans suivants (à écrire au moment de les exécuter)

Chaque plan produit un logiciel fonctionnel et testable :

- **Plan 2 — Supabase & données** : ajout `supabase-swift` (SPM), `SupabaseService`
  (client SDK), portage du login, modèles `Item/ItemCategory/ItemLocation/QRCode/
  MovementHistory`, migrations SQL (schéma étendu + transition depuis l'existant), bucket
  Storage `item-images`, `ItemService`/`ImageStorageService`/`QRCodeService`.
- **Plan 3 — Dashboard** : `DashboardViewModel` + `DashboardView` (cartes stats, alertes,
  raccourcis), branché sur `ItemService`.
- **Plan 4 — Matériel** : liste, détail, formulaire add/edit, image picker, filtres,
  recherche, archivage, badge, historique.
- **Plan 5 — QR / Scan** : `QRScannerView` (AVFoundation), ouverture fiche, association QR
  vierge, génération (CoreImage), changement rapide de statut + `movement_history`.

> Les détails de code des plans 3‑5 dépendent des résultats des plans 1‑2 (noms réels de
> colonnes, signatures de services) : ils sont rédigés juste avant exécution pour rester
> exacts, conformément à la skill writing-plans.
