struct ViewModel {
    let amount = ∞(Double(0))∞
    let amountMax = Double(100.0)
}

let vm = ViewModel()

let stepper = UIStepper()
stepper.maximumValue = vm.amountMax
stepper∞stepper.value <=∞=> vm.amount

let slider = UISlider()
slider.maximumValue = Float(vm.amountMax)
slider∞slider.value <~∞~> vm.amount

stepper.value += 25.0
assert(slider.value == 25.0)
assert(vm.amount.source.value == 25.0)

slider.value += 30.0
assert(stepper.value == 55.0)
assert(vm.amount.source.value == 55.0)

println("slider: \(slider.value) stepper: \(stepper.value)")
