(lang dune 2.8)
(version 0.5.2)
(name faad)
(source (github savonet/ocaml-faad))
(license GPL-2.0)
(authors "The Savonet Team <savonet-users@lists.sourceforge.net>")
(maintainers "Romain Beauxis <toots@rastageeks.org>")

(generate_opam_files true)
(use_standard_c_and_cxx_flags false)

(package
 (name faad)
 (synopsis "Bindings for the faad library which provides functions for decoding AAC audio files")
 (depends
  conf-faad
  conf-pkg-config
  dune
  dune-configurator)
)
