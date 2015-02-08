let progbar = UIProgressView()

// UIProgressView goes from 0.0-1.0, so map the slider's percentage complete to the progress value 
vm.amount.map({ Float($0 / vm.amountMax) }) ∞=> progbar∞progbar.progress

vm.amount.value += 20

assert(slider.value == 75.0)
assert(stepper.value == 75.0)
assert(progbar.progress == 0.75)

println("slider: \(slider.value) stepper: \(stepper.value) progress: \(progbar.progress)")
