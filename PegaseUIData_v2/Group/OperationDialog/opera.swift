
//  Untitled.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 20/05/2025.
//
//

import Combine
import Foundation
import SwiftUI

//func saveActionsMulti() {
//
//        printTimeElapsedWhenRunningCode(title:"saveActions Multi") {
//            self.contextSaveEdition()
//
//            guard let transactions = transactionManager.selectedTransactions else { return }
//
//
//            /// Multiple value
//            for transaction in transactions {
//
//                let index = popUpStatut.indexOfSelectedItem
//                let statut = transaction.status ?? 0
//                if index == 3 && statut.type == 2 {
//
//                    let _ = dialogOKCancel(question: "Ok?", text: "Impossible de modifier la transaction.\nLa transaction est verrouillée\nLe statut est 'Réalisé'")
//                    continue
//                }
//
//                transaction.dateModifie = Date()
//
//                // DatePointage
//                if (setCheck_In_Date.count > 1 ) || setCheck_In_Date.count == 1 {
//                    transaction.datePointage  = datePointage.dateValue.noon
//                }
//
//                // DateOperation
//                if (setDateOperation.count > 1 && date4 != nil) || setDateOperation.count == 1 {
//                    transaction.dateOperation  = dateOperation.dateValue.noon
//                }
//
//                // Relevé bancaire
//                if (setReleve.count > 1 && textFieldReleveBancaire.stringValue != "") || setReleve.count == 1 {
//                    transaction.bankStatement = textFieldReleveBancaire.doubleValue
//                }
//
//                // ModePaiement
//                if (setModePaiement.count > 1 && popUpModePaiement.indexOfSelectedItem != 0) || setModePaiement.count == 1 {
//                    let menuItem = self.popUpModePaiement.selectedItem
//                    let entityMode = menuItem?.representedObject as! EntityPaymentMode
//                    transaction.paymentMode = entityMode
//                }
//
//                // Statut
//                if (setStatut.count > 1 && popUpStatut.indexOfSelectedItem != 0) || setStatut.count == 1 {
//                    let item = self.popUpStatut.selectedItem
//                    let statut = Int16(item?.tag ?? 0)
//                    transaction.statut = statut
//                }
//                // checkNumber
//                if (setNumber.count > 1 && numCheque.stringValue != "") || setNumber.count == 1 {
//                    let item = self.numCheque.stringValue
//                    transaction.checkNumber = item
//                }
//
//                // Operation Link
//                let transfert = popUpTransfert.indexOfSelectedItem
//                if (setTransfert.isEmpty == false && transfert > 1)  {
//                    createOperationLiee(oneOperation: transaction)
//                }
//                else {
//                    transaction.operationLiee = nil
//                }
//            }
//
//            resetListTransactions()
//
//            if resetOp == true {
//                self.resetOperation()
//            }
//        }
//    }
//
//    // MARK: - edition Operations
//    func editionOperations() {
//
//        guard let transactions = transactionManager.selectedTransactions else { return }
//
//        self.buttonSave.isEnabled = true
//
//        self.entityTransactions = transactions
//        if self.entityTransactions.count > 1 {
//
//
////            self.dateOperation.allowEmptyDate = true
////            self.dateOperation.showPromptWhenEmpty = true
////
////            self.datePointage.allowEmptyDate = true
////            self.datePointage.showPromptWhenEmpty = true
//
//            self.addBUtton.isEnabled = false
//            self.removeButton.isEnabled = false
//
//            self.outlineViewSSOpe.isEnabled = false
//
//        } else {
//
//            self.addBUtton.isEnabled = true
//            let sousOperation = self.entityTransactions.first?.sousOperations?.allObjects as! [EntitySousOperations]
//            if sousOperation.count > 1 {
//                self.removeButton.isEnabled = true
//            } else {
//                self.removeButton.isEnabled = false
//            }
//
//            self.outlineViewSSOpe.isEnabled = true
//            self.textFieldMontant.isEnabled = true
//
//            self.splitTransactions.removeAll()
//            self.outlineViewSSOpe.isEnabled = true
//            self.outlineViewSSOpe.reloadData()
//
////            self.pieChartView.data = nil
////            self.pieChartView.data?.notifyDataChanged()
////            self.pieChartView.notifyDataSetChanged()
//        }
//
//        self.splitTransactions.removeAll()
//        self.outlineViewSSOpe.reloadData()
//
//        self.setDateOperation.removeAll()
//        self.setCheck_In_Date.removeAll()
//        self.setModePaiement.removeAll()
//        self.setMontant.removeAll()
//        self.setReleve.removeAll()
//        self.setStatut.removeAll()
//        self.setNumber.removeAll()
//        self.setTransfert.removeAll()
//
//        for quake in quakes {
//
//            let bankStatement = quake.bankStatement
//            self.setReleve.insert(bankStatement)
//
//            let amount = quake.amount
//            setMontant.insert(amount)
//
//            let modePaiement = quake.paymentMode?.name!
//            self.setModePaiement.insert(modePaiement ?? "modePaiement")
//
//            let statut = quake.statut
//            self.setStatut.insert(statut)
//
//            if let number = quake.checkNumber {
//                self.setNumber.insert(number)
//            } else {
//                self.setNumber.insert("")
//            }
//
//            let compteLie = quake.operationLiee?.account
//            let transfert = compteLie?.initAccount?.codeAccount ?? ""
//            self.setTransfert.insert(transfert)
//
//            let datePointage = quake.datePointage ?? Date()
//            self.setCheck_In_Date.insert(datePointage)
//
//            let dateOperation = quake.dateOperation ?? Date()
//            self.setDateOperation.insert(dateOperation)
//        }
//
//        if setNumber.count > 1 {
//            self.numCheque.stringValue =  ""
//            self.numCheque.alignment =  .left
//            self.numCheque.placeholderString = Localizations.Transaction.MultipleValue
//        } else {
//            self.numCheque.stringValue = setNumber.first!
//            self.numCheque.alignment =  .right
//            self.numCheque.placeholderString = ""
//        }
//
//        if setReleve.count > 1 {
//            self.textFieldReleveBancaire.stringValue =  ""
//            self.textFieldReleveBancaire.alignment =  .left
//            self.textFieldReleveBancaire.placeholderString = Localizations.Transaction.MultipleValue
//        } else {
//            self.textFieldReleveBancaire.doubleValue = setReleve.first!
//            self.textFieldReleveBancaire.alignment =  .right
//            self.textFieldReleveBancaire.placeholderString = ""
//        }
//
//        if setMontant.count > 1 {
//            textFieldMontant.stringValue =  ""
//            textFieldMontant.alignment =  .left
//            textFieldMontant.placeholderString = Localizations.Transaction.MultipleValue
//        } else {
//            let montant = setMontant.first!
//            self.textFieldMontant.alignment =  .right
//            self.textFieldMontant.doubleValue = abs(montant)
//            textFieldMontant.placeholderString = ""
//            textFieldMontant.textColor = montant < 0 ? NSColor.red : NSColor.green
//            //            signeMontant.state = montant < 0 ? .on : .off
//        }
//
//        if setCheck_In_Date.count > 1 {
//            self.date5 = nil
////            datePointage.updateControlValue(nil)
//        } else {
//            datePointage.dateValue = setCheck_In_Date.first!
//        }
//
//        if setDateOperation.count > 1 {
//            self.date4 = nil
////            dateOperation.updateControlValue(nil)
//        } else {
//            dateOperation.dateValue = setDateOperation.first!
//        }
//
//        if setModePaiement.count > 1 && popUpModePaiement.itemTitle(at: 0) != Localizations.Transaction.MultipleValue {
//            let menuItemMultiplevalue = getMenuItemMultiplevalue()
//            menuItemMultiplevalue.action = #selector(optionModePaiement(menuItem:))
//
//            self.popUpModePaiement.menu?.insertItem(menuItemMultiplevalue, at: 0)
//            self.popUpModePaiement.selectItem(at: 0)
//
//        } else {
//
//            // one item select
//            var mode = popUpModePaiement.itemTitle(at: 0)
//            if mode == Localizations.Transaction.MultipleValue {
//                self.popUpModePaiement.menu?.removeItem(at: 0)
//                mode = self.popUpModePaiement.itemTitle(at: 0)
//            }
//            self.popUpModePaiement.selectItem(withTitle: setModePaiement.first ?? mode)
//            if self.popUpModePaiement.indexOfSelectedItem == -1 {
//                self.popUpModePaiement.selectItem(at: 0)
//            }
//            if mode == Localizations.PaymentMethod.Check {
//                self.numCheque.isHidden = false
//                self.numberCheck.isHidden = false
//            } else {
//                self.numCheque.isHidden = true
//                self.numberCheck.isHidden = true
//            }
//        }
//
//        if setStatut.count > 1 && popUpStatut.itemTitle(at: 0) != Localizations.Transaction.MultipleValue {
//            let menuItem = getMenuItemMultiplevalue()
//            menuItem.action = #selector(optionStatut(menuItem:))
//
//            self.popUpStatut.menu?.insertItem(menuItem, at: 0)
//            self.popUpStatut.selectItem(at: 0)
//
//        } else {
//            let mode = popUpStatut.itemTitle(at: 0)
//            if mode == Localizations.Transaction.MultipleValue {
//                self.popUpStatut.menu?.removeItem(at: 0)
//            }
//            let statut = Int16(0)
//            self.popUpStatut.selectItem(at: (Int(setStatut.first ?? statut)))
//        }
//
//        if setTransfert.count > 1 && popUpTransfert.itemTitle(at: 0) != Localizations.Transaction.MultipleValue {
//
//            let menuItemMultiplevalue = getMenuItemMultiplevalue()
//            menuItemMultiplevalue.action = #selector(optionAccount(menuItem:))
//
//            popUpTransfert.menu?.insertItem(menuItemMultiplevalue, at: 0)
//            popUpTransfert.selectItem(at: 0)
//            nameCompte.stringValue = Localizations.Transaction.MultipleValue
//            nameTitulaire.stringValue = Localizations.Transaction.MultipleValue
//            prenomTitulaire.stringValue = Localizations.Transaction.MultipleValue
//        } else {
//            var transfert = popUpTransfert.itemTitle(at: 0)
//            if transfert == Localizations.Transaction.MultipleValue {
//
//                popUpTransfert.menu?.removeItem(at: 0)
//                transfert = popUpTransfert.itemTitle(at: 0)
//            }
//            let linkedAccount = quakes[0].operationLiee?.account
//            if linkedAccount != nil {
//                popUpTransfert.selectItem(withTitle: setTransfert.first ?? transfert)
//                nameCompte.stringValue = (linkedAccount?.name)!
//                nameTitulaire.stringValue = (linkedAccount?.identity?.name)!
//                prenomTitulaire.stringValue = (linkedAccount?.identity?.surName)!
//            } else {
//                popUpTransfert.selectItem(at: 0)
//                nameCompte.stringValue = ""
//                nameTitulaire.stringValue = ""
//                prenomTitulaire.stringValue = ""
//            }
//        }
//        resignFirstResponder()
//
//        if quakes.count == 1 {
//            splitTransactions = quakes.first?.sousOperations?.allObjects as! [EntitySousOperations]
//            self.outlineViewSSOpe.reloadData()
//
//            self.updateChartData(quakes: quakes.first!)
//            self.setDataCount()
//        }
//    }
//
//    // MARK: - resetOperation
//    func resetOperation() {
//
//        self.entityTransactions.removeAll()
//
//        self.edition = false
//        self.modeTransaction.title = Localizations.Transaction.ModeCreation
//        self.modeTransaction.layer?.backgroundColor = NSColor.orange.cgColor
//
//        self.modeTransaction2.title = Localizations.Transaction.ModeCreation
//        self.modeTransaction2.layer?.backgroundColor = NSColor.orange.cgColor
//
////        self.buttonSave.isEnabled = false
////        self.addBUtton.isEnabled = true
////        self.removeButton.isEnabled = false
////
////        self.addView.isHidden = false
//
//        self.setDateOperation.removeAll()
//        self.setCheck_In_Date.removeAll()
//        self.setModePaiement.removeAll()
//        self.setReleve.removeAll()
//        self.setStatut.removeAll()
//        self.setNumber.removeAll()
//        self.setTransfert.removeAll()
//
//        self.setDateOperation.insert(Date())
//        self.setCheck_In_Date.insert(Date())
//        self.setModePaiement.insert("string")
//        self.setReleve.insert(0)
//        self.setStatut.insert(0)
//        self.setNumber.insert("")
//
//        self.entityPreference = Preference.shared.getAllData()
//
//        self.loadAccount()
//        self.popUpTransfert.itemTitle(at: 0)
//        self.nameCompte.stringValue = ""
//        self.nameTitulaire.stringValue = ""
//        self.prenomTitulaire.stringValue = ""
//
//        self.loadStatut()
//        self.popUpStatut.selectItem(at: Int((entityPreference?.statut)!))
//
//        self.dateOperation.dateValue = Date()
//        self.datePointage.dateValue = Date()
//
//        self.loadModePaiement()
//        self.popUpModePaiement.selectItem(withTitle: (entityPreference?.paymentMode?.name)!)
//
//        self.textFieldReleveBancaire.doubleValue = 0.0
//        self.textFieldReleveBancaire.placeholderString = ""
//
//        self.numCheque.stringValue = ""
//        self.numCheque.placeholderString = ""
//
//        self.textFieldMontant.doubleValue = 0.0
//
//        self.splitTransactions.removeAll()
//        self.outlineViewSSOpe.isEnabled = true
//        self.outlineViewSSOpe.reloadData()
//
////        self.pieChartView.data = nil
////        self.pieChartView.data?.notifyDataChanged()
////        self.pieChartView.notifyDataSetChanged()
//
////        self.dateOperation.allowEmptyDate = false
////        self.dateOperation.showPromptWhenEmpty = false
////        self.dateOperation.referenceDate = Date()
////        self.dateOperation.dateFieldPlaceHolder = Localizations.Transaction.Multi
//        self.dateOperation.dateValue = Date()
//
////        self.datePointage.allowEmptyDate = false
////        self.datePointage.showPromptWhenEmpty = false
////        self.datePointage.referenceDate = Date()
////        self.datePointage.dateFieldPlaceHolder = Localizations.Transaction.Multi
//        self.datePointage.dateValue = Date()
//    }
