(*
 Copyright (C) 2003-2008 Samuel Mimram

 This file is part of Ocaml-faad.

 This library is free software; you can redistribute it and/or
 modify it under the terms of the GNU Lesser General Public
 License as published by the Free Software Foundation; either
 version 2.1 of the License, or (at your option) any later version.

 This library is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 Lesser General Public License for more details.

 You should have received a copy of the GNU Lesser General Public
 License along with this library; if not, write to the Free Software
 Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 *)

type t

exception Error of int

exception Failed

external error_message : int -> string = "ocaml_faad_get_error_message"

let () =
  Callback.register_exception "ocaml_faad_exn_error" (Error 0);
  Callback.register_exception "ocaml_faad_exn_failed" Failed

external create : unit -> t = "ocaml_faad_open"

(* TODO: finalizer *)
external close : t -> unit = "ocaml_faad_close"

external init : t -> string -> int -> int -> int * int * int = "ocaml_faad_init"
external init2 : t -> string -> int -> int -> int * int = "ocaml_faad_init2"

external decode : t -> string -> int -> int -> int * (float array array) = "ocaml_faad_decode"

let find_frame buf =
  let i = ref 0 in
  let found = ref false in
    while !i < String.length buf - 1 && not !found do
      if buf.[!i] = '\255' then
        if int_of_char buf.[!i+1] land 0xf6 = 0xf0 then
          found := true
        else
          incr i
      else
        incr i
    done;
    if !found then !i else raise Not_found

(*
module Mp4 =
struct
  type decoder = t

  type t

  type track = int

  type sample = int

  let is_mp4 s =
    assert (String.length s >= 8);
    s.[4] = 'f' && s.[5] = 't' && s.[6] = 'y' && s.[7] = 'p'

  external open_read : bool -> (int -> (string * int * int)) -> (string -> int) option -> (int -> int) option -> (unit -> int) option -> t = "ocaml_faad_mp4_open_read"

  external open_read_fd : bool -> Unix.file_descr -> t = "ocaml_faad_mp4_open_read_fd"

  let openfile ?write ?seek ?trunc read = open_read false read write seek trunc

  let openfile_fd = open_read_fd false

  external tracks : t -> int = "ocaml_faad_mp4_total_tracks"

  external find_aac_track : t -> track = "ocaml_faad_mp4_find_aac_track"

  external init : t -> decoder -> track -> int * int = "ocaml_faad_mp4_init"

  external samples : t -> track -> int = "ocaml_faad_mp4_num_samples"

  external sample_duration : t -> track -> sample -> int = "ocaml_faad_mp4_get_sample_duration"

  external sample_offset : t -> track -> sample -> int = "ocaml_faad_mp4_get_sample_offset"

  external read_sample : t -> track -> sample -> string = "ocaml_faad_mp4_read_sample"

  external decode : t -> track -> sample -> decoder -> float array array = "ocaml_faad_mp4_decode"

  external metadata : t -> (string * string) array = "ocaml_faad_mp4_metadata"
end
*)
