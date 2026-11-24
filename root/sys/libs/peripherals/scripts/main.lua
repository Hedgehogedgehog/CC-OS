function ScanForMachines()
	
	local peripherals = peripheral.getNames()
	for key,peripherals in pairs(peripherals) do
		print (peripherals)
	end

end

ScanForMachines()