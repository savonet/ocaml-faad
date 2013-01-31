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

let usage = "usage: aac2wav [options] source destination"

let () =
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

  let buflen = 1024 in
  let buf = String.create buflen in
  let f = Unix.openfile !src [Unix.O_RDONLY] 0o400 in
  let dec = Faad.create () in

  let outbuf = ref "" in
  let fill_out channels a =
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

  let decode_mp4 () =
    let mp4 = Faad.Mp4.openfile_fd f in
    let track = Faad.Mp4.find_aac_track mp4 in
    let samplerate, channels = Faad.Mp4.init mp4 dec track in
    let fill_out = fill_out channels in
    let samples = Faad.Mp4.samples mp4 track in
    Printf.printf "Input file: %d channels at %d Hz.\n%!" channels samplerate;
    Array.iter (fun (i,t) -> Printf.printf "%s: %s\n%!" i t) (Faad.Mp4.metadata mp4);
    Printf.printf "%d tracks (AAC track: %d).\n%!" (Faad.Mp4.tracks mp4) track;
    Printf.printf "%d samples.\n" samples;
    for i = 0 to samples - 1 do
      Printf.printf "Decoding sample: %d / %d (%d bytes).\r%!" i samples (String.length !outbuf);
      let a = Faad.Mp4.decode mp4 track i dec in
      fill_out a
    done;
    Printf.printf "\n%!";
    channels, samplerate, !outbuf
  in

  let decode_aac () =
    let consumed = ref buflen in
    let fill_in () =
      String.blit buf !consumed buf 0 (buflen - !consumed);
      let n = Unix.read f buf (buflen - !consumed) !consumed in
      let n = !consumed + n in
      consumed := 0;
      n
    in

    let offset, samplerate, channels = Faad.init dec buf 0 (Unix.read f buf 0 buflen) in
    let fill_out = fill_out channels in
    Printf.printf "Input file: %d channels at %d Hz.\n%!" channels samplerate;
    ignore (Unix.lseek f offset Unix.SEEK_SET);

    Printf.printf "Decoding AAC...\n%!";
    try
      while true do
        let r = fill_in () in
        if r = 0 then raise End_of_file;
        if buf.[0] <> '\255' then raise End_of_file;
        let c, a = Faad.decode dec buf 0 r in
        consumed := c;
        fill_out a
      done;
      channels, samplerate, !outbuf
    with
    | End_of_file
    | Faad.Failed ->
      channels, samplerate, !outbuf
    | Faad.Error n as e ->
      Printf.printf "Faad error %d: %s\n%!" n (Faad.error_message n);
      raise e
  in

  let channels, samplerate, outbuf =
    if Filename.check_suffix !src ".aac" || Filename.check_suffix !src ".AAC" then
      decode_aac ()
    else
      decode_mp4 ()
  in

  (* Do the wav stuff. *)
  let datalen = String.length outbuf in
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
  output_string oc outbuf;
  close_out oc;
  Gc.full_major ()
