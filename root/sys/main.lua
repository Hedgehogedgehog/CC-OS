function ScanForMachines()
	
	local peripherals = peripheral.getNames()
	for key,peripherals in pairs(peripherals) do
		return (peripherals)
	end

end

print(ScanForMachines)