open Cmdliner

let ext = Arg.(
  value & opt int (-1) & info ["exit"]
    ~doc:"the build exit with the code $(docv)" ~docv:"EXT")

let signal = Arg.(
  value & opt int (-1) & info ["signal"]
    ~doc:"signaled with the code $(docv)" ~docv:"SIG")

let stop = Arg.(
  value & opt int (-1) & info ["stop"]
    ~doc:"process stopped with the code $(docv)" ~docv:"STOP")

let path_out = Arg.(
  required & pos 0 (some file) None & info []
    ~doc:"file path to stdout of opam build to triage" ~docv:"STDOUT")

let path_err = Arg.(
  required & pos 1 (some file) None & info []
    ~doc:"file path to stderr of opam build to triage" ~docv:"STDERR")

let triage ext signal stop path_out path_err =
  let p_status = Repo.(
    if not (ext = (-1)) then Exited ext
    else if not (signal = (-1)) then Signaled signal
    else Stopped stop) in
  let r =
    let buf = Buffer.create 512 in
    let string_of_path p =
      let ic = open_in p in
        Buffer.clear buf;
        Buffer.add_channel buf ic (in_channel_length ic);
        Buffer.contents buf in
    Repo.({ r_cmd = "opam"; r_args = []; r_env = [||]; r_cwd = "";
            r_duration = Time.min;
            r_stdout = string_of_path path_out;
            r_stderr = string_of_path path_err }) in
  let error = Result.error_of_exn (Repo.ProcessError (p_status, r)) in
  let status = Result.(Failed (analyze error, error)) in
  print_endline (Result.string_of_status status)

let scry_cmd =
  Term.(pure triage $ ext $ signal $ stop $ path_out $ path_err),
  Term.info "scry" ~doc:"analyze build results"

let () = match Term.eval scry_cmd with `Error _ -> exit 1 | _ -> exit 0
