import Foundation

extension Double {
    /// Affiche un entier sans décimales ("3"), un décimal avec ("1.5").
    var qtyDisplay: String {
        truncatingRemainder(dividingBy: 1) == 0 ? String(Int(self)) : String(self)
    }
}
