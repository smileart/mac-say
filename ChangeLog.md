v0.2.0 / 2017-02-16
===================

  * Added useful voices meta-information: gender, quality, "is it a joke?"-flag (WARNING: all the attributes values provided are highly subjective!)
  * Implemented searching for voices by more than one attribute (i.e. @voices.find_all &block delegation)
  * Improved/Fixed documentation

v.0.1.1 / 2017-01-30
====================

  * Fixed leaked `nil` output from the main lib file
  * Test code with colourful language deleted from the main lib file 🤦🏻‍♂️

v0.1.0 / 2017-01-30
===================

  * First version
  * Basic TTS (Strings/Multiline strings/Files)
  * Dynamic voices list parsing (based on the real `say` output)
  * Voices search (by one of the attributes: name / language / country)
  * Full test/docs coverage + CI configuration + fake `say` command for CI
