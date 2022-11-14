import UIKit
import Flutter
import CoreBluetooth

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, CBPeripheralDelegate {
    var centralManager: CBCentralManager!
    var lockPeripheral: CBPeripheral!
    var lockCharacteristic: CBCharacteristic!
    var lockServiceUuid: CBUUID!
    var lockCharacteristicUuid: CBUUID!

    var onVal: Data = Data.init(repeating: 1,count: 1)
    var offVal: Data = Data.init(repeating: 0,count: 1)
    var valToSet: Data!

  
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        let openLockChannel = FlutterMethodChannel(name: "hello2/openLockBLEServer",
                                                    binaryMessenger: controller.binaryMessenger)
        openLockChannel.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            // This method is invoked on the UI thread.
            guard call.method == "openLockBLEServer" else {
                result(FlutterMethodNotImplemented)
                return
            }
            
            //TODO need to validate uuid - CBUUID constructor does not throw error but app will crash if uuid is invalid
            let args = call.arguments as? [String]
            if args?.count != 3 {
                return
            }
            self.lockServiceUuid = CBUUID(string: args![0])
            self.lockCharacteristicUuid = CBUUID(string: args![1])
            
            if (args![2] == "open") {
                self.valToSet = self.onVal
            } else {
                self.valToSet = self.offVal
            }
            self.toggleLock(result: result)
            if (self.lockPeripheral == nil) {
                result("in process")
            } else {
                result(self.lockPeripheral.name)
            }

        })

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func toggleLock(result: FlutterResult) {
        print("setup centralmanager")
        if (centralManager == nil) {
            self.centralManager = CBCentralManager(delegate: self, queue: nil)
        }
        writeCharacteristicVal(val: valToSet);
    }
    
    func writeCharacteristicVal(val: Data) {
        print("attempt to write ")
        print(val.first)
        if (self.lockPeripheral != nil && self.lockCharacteristic != nil) {
            self.lockPeripheral!.writeValue(val, for: self.lockCharacteristic!, type: CBCharacteristicWriteType.withResponse)
        }
    }
}

extension AppDelegate: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {

        case .unknown:
            print("ble unknown")
        case .resetting:
            print("ble resetting")
        case .unsupported:
            print("ble unsupported")
        case .unauthorized:
            print("ble unauthorized")
        case .poweredOff:
            print("ble off")
        case .poweredOn:
            print("scanning")
            centralManager.scanForPeripherals(withServices: [self.lockServiceUuid])
        @unknown default:
            print("ble unknown")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        centralManager.stopScan()
        print("peripheral discovered: ")
        print(peripheral)
        self.lockPeripheral = peripheral
        self.lockPeripheral.delegate = self;

        print("name: " + (self.lockPeripheral.name ?? "not found"));
        centralManager.connect(self.lockPeripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("connected");
        peripheral.discoverServices([lockServiceUuid])
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        //print("services ")
        //print(self.lockPeripheral.services)
        if (self.lockPeripheral.services?.count != 1) {
            return
        }
        let service: CBService? = peripheral.services?[0]
        self.lockPeripheral.discoverCharacteristics([self.lockCharacteristicUuid], for: service!)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        //print("characteristics: ")
        //print(service.characteristics)
        self.lockCharacteristic = service.characteristics?[0]
        writeCharacteristicVal(val: valToSet)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        print("wrote value successfully")
    }
}

