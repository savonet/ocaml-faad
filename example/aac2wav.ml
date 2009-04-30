(*
 * Copyright 2009 Savonet team
 *
 * This file is part of OCaml-Vorbis.
 *
 * OCaml-Vorbis is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * OCaml-Vorbis is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with OCaml-Vorbis; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *)

(**
  * An aac to wav converter using ocaml-aac.
  *
  * @author Samuel Mimram
  *)

let bufsize = 16 * 1024

let src = ref ""
let dst = ref ""


open Unix


let output_int chan n =
  output_char chan (char_of_int ((n lsr 0) land 0xff));
  output_char chan (char_of_int ((n lsr 8) land 0xff));
  output_char chan (char_of_int ((n lsr 16) land 0xff));
  output_char chan (char_of_int ((n lsr 24) land 0xff))


let output_short chan n =
  output_char chan (char_of_int ((n lsr 0) land 0xff));
  output_char chan (char_of_int ((n lsr 8) land 0xff))


let progress_bar =
  let spin = ref 0 in
    (
      fun title pos tot ->
        let nbeq = 40 in
        let n = min (100. *. (float_of_int pos) /. (float_of_int tot)) 100. in
        let e = int_of_float (n /. 100. *. (float_of_int nbeq)) in
          Printf.printf "\r%s %6.2f%% [" title n;
          for i = 1 to e do Printf.printf "=" done;
          if e != nbeq then Printf.printf ">";
          for i = e + 2 to nbeq do Printf.printf " " done;
          Printf.printf "] ";
          incr spin;
          if !spin > 4 then spin := 1;
          Printf.printf "%c%!"
            (
              if n = 100. then ' '
              else
                match !spin with
                  | 1 -> '|'
                  | 2 -> '/'
                  | 3 -> '-'
                  | 4 -> '\\'
                  | _ -> failwith "this did not happen"
            )
    )


let usage = "usage: aac2wav [options] source destination"

let _ =
  Arg.parse
    []
    (
      let pnum = ref (-1) in
        (fun s -> incr pnum; match !pnum with
           | 0 -> src := s
           | 1 -> dst := s
           | _ -> Printf.eprintf "Error: too many arguments\n"; exit 1
        )
    ) usage;
  if !src = "" || !dst = "" then
    (
      Printf.printf "%s\n" usage;
      exit 1
    );

    (*
     (* For MP4 files *)
  let dec = Faad.create () in
  let mp4 =
    let f = Unix.openfile !src [Unix.O_RDONLY] 0o400 in
    let read n =
      Printf.printf "read: %d\n%!" n;
      let buf = String.create n in
      let len = Unix.read f buf 0 n in
        buf, 0, len
    in
    let seek n =
      Printf.printf "seek: %d\n%!" n;
      try
        ignore (Unix.lseek f n Unix.SEEK_SET); 0
      with
        | _ -> -1
    in
      Faad.Mp4.openfile ~seek read
  in
  let () =
    let tracks = Faad.Mp4.tracks mp4 in
      Printf.printf "%d tracks.\n%!" tracks
  in
  let track = Faad.Mp4.find_aac_track mp4 in
  let chans, samplerate = Faad.Mp4.init mp4 dec track in
    Printf.printf "Input file: %d channels at %d Hz.\n%!" chans samplerate;
     *)

  let buflen = 1024 in
  let buf = String.create buflen in
  let f = Unix.openfile !src [Unix.O_RDONLY] 0o400 in
  let dec = Faad.create () in
  let offset, samplerate, channels = Faad.init dec buf 0 (Unix.read f buf 0 buflen) in
    Printf.printf "Input file: %d channels at %d Hz.\n%!" channels samplerate;
    ignore (Unix.lseek f offset Unix.SEEK_SET);

    let outbuf = ref "" in
    let fill_out a =
      let tmplen = Array.length a.(0) in
      let tmp = String.create (tmplen * channels * 2) in
        for i = 0 to tmplen - 1 do
          for c = 0 to channels - 1 do
            let n = a.(c).(i) *. 32767. in
            let n = int_of_float n in
            tmp.[2 * (i * channels + c)] <- char_of_int (n land 0xff);
            tmp.[2 * (i * channels + c) + 1] <- char_of_int ((n lsr 8) land 0xff)
          done
        done;
        outbuf := !outbuf ^ tmp
    in
    let consumed = ref buflen in
    let fill_in () =
      String.blit buf !consumed buf 0 (buflen - !consumed);
      let n = Unix.read f buf (buflen - !consumed) !consumed in
      let n = !consumed + n in
        consumed := 0;
        n
    in
      (
        Printf.printf "Decoding AAC...\n%!";
        try
          while true do
            let r = fill_in () in
            if r = 0 then raise End_of_file;
            if buf.[0] <> '\255' then raise End_of_file;
            let c, a = Faad.decode dec buf 0 r in
              consumed := c;
              fill_out a
          done
        with
          | End_of_file
          | Faad.Failed -> Faad.close dec
      );

      (* Do the wav stuff. *)
      let datalen = String.length !outbuf in
      let oc = open_out_bin !dst in
        output_string oc "RIFF";
        output_int oc (4 + 24 + 8 + datalen);
        output_string oc "WAVE";
        output_string oc "fmt ";
        output_int oc 16;
        output_short oc 1; (* WAVE_FORMAT_PCM *)
        output_short oc channels; (* channels *)
        output_int oc samplerate; (* freq *)
        output_int oc (samplerate * channels * 2); (* bytes / s *)
        output_short oc (channels * 2); (* block alignment *)
        output_short oc 16; (* bits per sample *)
        output_string oc "data";
        output_int oc datalen;
        output_string oc !outbuf;
        close_out oc;
        Gc.full_major ()
