# Plan de test - Transaction Predicate Editor

## ✅ Corrections appliquées

Le crash `Fatal error: Unexpected class type: NSColor` a été **résolu**.

**Changement principal :**
- ✅ Filtrage sur `status?.name` au lieu de `statusString`
- ✅ Filtrage sur `paymentMode?.name` au lieu de `paymentModeString`

---

## 🧪 Tests à effectuer maintenant

### Test 1: Statut (LE PLUS IMPORTANT - était le problème)
**Objectif :** Vérifier que le filtrage sur status ne plante plus

1. Lancez l'application
2. Ouvrez la vue avec `TransactionFilterView()`
3. Créez un filtre : **`status == "Validé"`** (utilisez un nom de statut de votre BD)
4. Cliquez sur "Apply"

**Résultat attendu :**
- ✅ Pas de crash
- ✅ Les transactions avec ce statut s'affichent
- ✅ Dans la console : `✅ Fetch réussi: X résultats`

**Si ça plante :**
- Copiez-moi les logs de la console
- Vérifiez le nom exact de votre statut dans votre base de données

---

### Test 2: Mode de paiement
**Objectif :** Vérifier que le filtrage sur mode fonctionne

1. Créez un filtre : **`mode == "Carte bancaire"`** (utilisez un de vos modes)
2. Appliquez le filtre

**Résultat attendu :**
- ✅ Pas de crash
- ✅ Les transactions avec ce mode s'affichent

---

### Test 3: Date d'opération
**Objectif :** Vérifier les filtres sur date

1. Créez un filtre : **`dateOperation > [sélectionnez une date]`**
2. Appliquez le filtre

**Résultat attendu :**
- ✅ Transactions postérieures à cette date

---

### Test 4: Montant bancaire
**Objectif :** Vérifier les filtres numériques

1. Créez un filtre : **`bankStatement > 0`**
2. Appliquez le filtre

**Résultat attendu :**
- ✅ Transactions avec relevé bancaire positif

---

### Test 5: Filtre combiné
**Objectif :** Vérifier les combinaisons AND/OR

1. Créez un filtre : **`status == "Validé" AND dateOperation > [date récente]`**
2. Appliquez le filtre

**Résultat attendu :**
- ✅ Transactions validées ET récentes

---

## 📊 Interprétation des logs

### ✅ Succès
Si vous voyez ceci dans la console :
```
🔍 Application du prédicat...
   → NSPredicate format: status == "Validé"
   → Validation du prédicat...
   ✅ Prédicat valide
   → Conversion en SwiftData Predicate...
      [Parser] Format original: status == "Validé"
         [Binary] lhs='status', op='==', rhs='"Validé"'
         [Binary] Type parsé: string("Validé")
         [Binary] → Création prédicat String
         [Binary] Résultat: ✅
      [Parser] Résultat: ✅ Succès
   ✅ Prédicat SwiftData créé
   → Fetch en cours...
   ✅ Fetch réussi: 42 résultats
```

**C'EST BON !** Le module fonctionne correctement.

### ❌ Échec
Si vous voyez :
```
❌ Erreur de fetch : ...
```

**Action :** Copiez-moi le message d'erreur complet.

---

## ⚠️ Champs potentiellement problématiques

### `amount` (montant total)
`amount` est une **propriété calculée** qui peut poser problème.

**Si le filtre `amount > 100` plante :**

**Option 1 :** Retirer `amount` des templates
- Ouvrir `TransactionPredicateEditorView.swift`
- Commenter ou supprimer le template pour `amount` (lignes ~192-204)

**Option 2 :** Filtrer en mémoire (voir `DEBUG_GUIDE.md` section "Problème spécifique: amount")

**Option 3 :** Utiliser `bankStatement` à la place
- `bankStatement` est une propriété stockée qui fonctionne toujours

---

## 🎯 Checklist de validation

- [ ] **Test 1 (Status)** - Le plus important ⭐
- [ ] **Test 2 (Mode)** - Important aussi
- [ ] **Test 3 (Date)** - Devrait fonctionner
- [ ] **Test 4 (BankStatement)** - Devrait fonctionner
- [ ] **Test 5 (Combiné)** - Validation finale
- [ ] Vérifier que les résultats sont corrects
- [ ] Vérifier les performances (devrait être rapide)

---

## 📝 Résultats à me communiquer

### Si tout fonctionne ✅
Dites-moi simplement : **"Tout fonctionne !"**

### Si un test échoue ❌
Communiquez-moi :
1. **Quel test** a échoué
2. **Le message d'erreur** exact (de la console)
3. **Les logs** de la console (copiez toute la sortie depuis `🔍 Application du prédicat...`)

Exemple :
```
Test 1 échoué
Erreur : Fatal error: ...
Logs :
🔍 Application du prédicat...
[... copiez tout ...]
```

---

## 🚀 Après les tests

### Si tout fonctionne
Vous pourrez :
1. **Désactiver les logs de debug** (voir `DEBUG_GUIDE.md`)
2. **Intégrer la vue** dans votre app principale
3. **Personnaliser l'interface** selon vos besoins

### Si des problèmes persistent
Je corrigerai en fonction de vos retours et logs.

---

## 💡 Aide rapide

| Problème | Solution |
|----------|----------|
| Crash sur `status` | Vérifiez que le nom du statut existe dans votre BD |
| Crash sur `amount` | Utilisez `bankStatement` à la place ou désactivez ce champ |
| Aucun résultat | Vérifiez que des transactions correspondent au filtre |
| Console vide | Vérifiez que Xcode console est bien ouverte (Cmd+Shift+Y) |

---

**Bon test ! 🎉**

Lancez l'application et testez en particulier le **Test 1 (Status)** qui était le problème principal.
