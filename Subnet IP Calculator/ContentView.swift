//
//  ContentView.swift
//  Subnet IP Calculator
//
//  Created by Anthony Paris on 14/11/2024.
//

import SwiftUI

struct Subnet: Hashable, Identifiable {
    let id = UUID()
    let ipAddress: String
    let subnetMask: String
    let networkAddress: String
    let broadcastAddress: String
    let firstHost: String
    let lastHost: String
    let totalHosts: Int
}

extension String {
    func ipToDecimal() -> UInt32? {
        let parts = self.split(separator: ".").compactMap { UInt32($0) }
        guard parts.count == 4 else { return nil }
        return (parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3]
    }
    
    static func fromDecimal(_ decimal: UInt32) -> String {
        return "\((decimal >> 24) & 0xFF).\( (decimal >> 16) & 0xFF).\( (decimal >> 8) & 0xFF).\(decimal & 0xFF)"
    }
}

struct SubnetCalculator {
    static func calculateSubnet(ip: String, cidr: Int) -> Subnet? {
        guard let ipDecimal = ip.ipToDecimal() else { return nil }
        
        let maskBits = (UInt32(0xFFFFFFFF) << (32 - UInt32(cidr))) & 0xFFFFFFFF
        let maskString = String.fromDecimal(maskBits)
        
        let networkDecimal = ipDecimal & maskBits
        let broadcastDecimal = networkDecimal | (~maskBits)

        let firstHost = String.fromDecimal(networkDecimal + 1)
        let lastHost = String.fromDecimal(broadcastDecimal - 1)
        
        let totalHosts = Int(broadcastDecimal - networkDecimal - 1)
        
        return Subnet(
            ipAddress: ip,
            subnetMask: maskString,
            networkAddress: String.fromDecimal(networkDecimal),
            broadcastAddress: String.fromDecimal(broadcastDecimal),
            firstHost: firstHost,
            lastHost: lastHost,
            totalHosts: totalHosts
        )
    }

    static func calculateSubnet(ip: String, subnetMask: String) -> Subnet? {
        guard subnetMask.ipToDecimal() != nil else { return nil }
        let cidr = (0..<32).reduce(0) { $0 + (($1 >> (31 - $0)) & 1) }
        return calculateSubnet(ip: ip, cidr: cidr)
    }
}

struct ContentView: View {
    @State private var ipAddress: String = ""
    @State private var cidr: Int = 24
    @State private var subnetMask: String = "255.255.255.0"
    @State private var subnet: Subnet?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var useCIDR = true

    var body: some View {
        VStack(spacing: 20) {
            Text("Subnet IP Calculator").font(.title)
            
            TextField("Adresse IP (ex. 192.168.1.0)", text: $ipAddress)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                #if os(iOS)
                    .keyboardType(.numbersAndPunctuation)
                #endif

            Toggle("Utiliser la notation CIDR", isOn: $useCIDR)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
            
            if useCIDR {
                HStack {
                    Text("Notation CIDR:")
                    Stepper(value: $cidr, in: 0...32) {
                        Text("\(cidr)")
                    }
                }
            } else {
                TextField("Masque de sous réseaux (ex. 255.255.255.0)", text: $subnetMask)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    #if os(iOS)
                        .keyboardType(.numbersAndPunctuation)
                    #endif
            }
            
            Button(action: {
                let ipRegex = "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|255)\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|255)$"
                let maskRegex = "^((255\\.){3}(0|128|192|224|240|248|252|254|255))$"
                let ipPredicate = NSPredicate(format:"SELF MATCHES %@", ipRegex)
                let maskPredicate = NSPredicate(format:"SELF MATCHES %@", maskRegex)
                
                if !ipPredicate.evaluate(with: self.ipAddress) {
                    self.alertMessage = "Veuillez entrer un adresse IP valide."
                    self.showingAlert = true
                    return
                }
                
                if self.useCIDR && !(0...32).contains(self.cidr) {
                    self.alertMessage = "Le CIDR doit être compris entre 0 et 32."
                    self.showingAlert = true
                    return
                }
                
                if !self.useCIDR && !maskPredicate.evaluate(with: self.subnetMask) {
                    self.alertMessage = "Veuillez entrer un masque de sous-réseaux valide."
                    self.showingAlert = true
                    return
                }
                
                if let calculatedSubnet = self.useCIDR ?
                    SubnetCalculator.calculateSubnet(ip: self.ipAddress, cidr: self.cidr) :
                    SubnetCalculator.calculateSubnet(ip: self.ipAddress, subnetMask: self.subnetMask) {
                    self.subnet = calculatedSubnet
                } else {
                    self.alertMessage = "Erreur de calcul. Veuillez vérifier les données saisies."
                    self.showingAlert = true
                }
            }) {
                Text("Calculer")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Entré invalide"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }

            if let subnet = subnet {
                SubnetDetailsView(subnet: subnet)
            }
        }
        .padding()
    }
}

struct SubnetDetailsView: View {
    let subnet: Subnet
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Adresse réseaux: \(subnet.networkAddress)")
            Text("Adresse de diffusion: \(subnet.broadcastAddress)")
            Text("Premier hôte: \(subnet.firstHost)")
            Text("Dernier hôte: \(subnet.lastHost)")
            Text("Nombre total d'hôtes: \(subnet.totalHosts)")
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

@main
struct IPSubnetCalculatorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
