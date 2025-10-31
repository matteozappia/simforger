# simforger

a simple wrapper around simforge that makes it way easier to run ios apps on apple silicon simulators.

this started as a fork but ended up being basically just a bash script that automates all the annoying parts. put your ipa files in the apps folder, run the script, pick your app and simulator, and you're done.

## what it does

simforger.sh handles the whole process for you:

- extracts ipa files from the apps folder automatically
- converts apps for simulator compatibility using simforge
- signs frameworks, extensions, and the main app bundle
- installs to your simulator
- optionally launches the app

## how to use

1. put your decrypted ipa files in the `apps` folder (or extract them yourself)
2. run `./simforger.sh`
3. pick which app you want to install
4. pick which simulator to use (or use the booted one)
5. wait for it to convert, sign, and install
6. launch if you want

that's it. no need to manually run simforge convert, codesign everything, or figure out simulator uuids.

## requirements

- macos with apple silicon
- xcode command line tools (for simctl and codesign)
- a decrypted ipa file (or extracted .app bundle)

the script will download simforge automatically if it's not found in your path or in the script directory.

## how it works

simforge itself modifies mach-o binary headers to make arm64 ios apps work on simulators. this script just wraps all that in a simple interactive menu so you don't have to remember all the commands and steps.
