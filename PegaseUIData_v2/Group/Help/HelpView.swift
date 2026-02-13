//
//  HelpView.swift
//  PegaseUIData
//
//  Created by thierryH24 on 24/06/2025.
//

import SwiftUI
import Combine


struct HelpView: View {
    
    @State var str = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(String(localized: "Help_Title",table: "Help"))
                    .font(.largeTitle)
                    .bold()

                Group {
                    Text(String(localized: "Help_Section_TOC",table: "Help"))
                        .font(.title2)
                        .bold()
                    VStack(alignment: .leading, spacing: 8) {
//                                  String(localized: "Settings",table: "Menu" )
                        let str = String(localized : "Help_TOC_Account",     table : "Help")
                        Text("• \(str)")
                        Text("• \(String(localized : "Help_TOC_Transactions",table : "Help"))")
                        Text("• \(String(localized : "Help_TOC_PaymentModes",table : "Help"))")
                        Text("• \(String(localized : "Help_TOC_Charts",      table : "Help"))")
                        Text("• \(String(localized : "Help_TOC_Save",        table : "Help"))")
                        Text("• \(String(localized : "Help_TOC_FAQ",         table : "Help"))")
                    }
                }

                Divider()

                Group {
                    Text(String(localized: "Help_Account_Title",table: "Help"))
                        .font(.title3)
                        .bold()
                    Text(String(localized: "Help_Account_Text",table: "Help"))
                }

                Group {
                    Text(String(localized: "Help_Transactions_Title",table: "Help"))
                        .font(.title3)
                        .bold()
                    Text(String(localized: "Help_Transactions_Text",table: "Help"))
                }

                Group {
                    Text(String(localized: "Help_PaymentModes_Title",table: "Help"))
                        .font(.title3)
                        .bold()
                    Text(String(localized: "Help_PaymentModes_Text",table: "Help"))
                }

                Group {
                    Text(String(localized: "Help_Charts_Title",table: "Help"))
                        .font(.title3)
                        .bold()
                    Text(String(localized: "Help_Charts_Text",table: "Help"))
                }

                Group {
                    Text(String(localized: "Help_Save_Title",table: "Help"))
                        .font(.title3)
                        .bold()
                    Text(String(localized: "Help_Save_Text",table: "Help"))
                }

                Group {
                    Text(String(localized: "Help_FAQ_Title",table: "Help"))
                        .font(.title3)
                        .bold()
                    Text(String(localized: "Help_FAQ_Text",table: "Help"))
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle(String(localized: "Help_Navigation_Title",table: "Help"))
    }
}
