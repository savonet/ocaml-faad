module C = Configurator.V1

let () =
  C.main ~name:"faad2-pkg-config" (fun c ->
      let default : C.Pkg_config.package_conf =
        { libs = ["-lfaad"]; cflags = [] }
      in
      let conf =
        match C.Pkg_config.get c with
          | None -> default
          | Some pc -> (
              match
                C.Pkg_config.query_expr_err pc ~package:"faad2" ~expr:"faad2"
              with
                | Error _ -> default
                | Ok deps -> deps)
      in
      C.Flags.write_sexp "c_flags.sexp" conf.cflags;
      C.Flags.write_sexp "c_library_flags.sexp" conf.libs)
