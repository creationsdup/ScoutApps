import Foundation

extension Double {
    /// Affiche un entier sans décimales ("3"), un décimal avec ("1.5").
    public var qtyDisplay: String {
        truncatingRemainder(dividingBy: 1) == 0 ? String(Int(self)) : String(self)
    }

    /// Montant en euros, format FR (ex. "12,50 €").
    public var euroDisplay: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        f.locale = Locale(identifier: "fr_FR")
        return f.string(from: NSNumber(value: self)) ?? "\(self) €"
    }
}
