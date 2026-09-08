function ScanForMachines()
	
	local peripherals = peripheral.getNames()
	for key,peripherals in pairs(peripherals) do
		return (peripherals)
	end

end

shell.run("clear")
print("OS initializing...")