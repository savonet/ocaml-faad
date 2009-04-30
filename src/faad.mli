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

(**
  * Library for decoding AAC and AAC+ streams.
  *
  * @author Samuel Mimram
  *)

(** Internal state of a decoder. *)
type t

(** An error occured... *)
exception Error of int
exception Failed

(** Get the error message corresponding to a raised [Error]. *)
val error_message : int -> string

(** Create a new decoder. *)
val create : unit -> t

(** Close a decoder. *)
val close : t -> unit

(** [init dec buf ofs len] initializes a decoder given the [len] bytes of data
  * in [buf] starting at offset [ofs]. It returns the offset (number of bytes to
  * skip), the samplerate and the number of channels of the stream. This function
  * should be used for AAC data. For MP4 files, [init2] should be used instead.
  *)
val init : t -> string -> int -> int -> int * int * int

(** Same as [init] but for MP4 files. Returns the samplerate and the number of
  * channels. *)
val init2 : t -> string -> int -> int -> int * int

(** [decode dec buf ofs len] decodes at most [len] bytes of data in [buf]
  * starting at offset [ofs]. It returns the number of bytes actually decoded
  * and the decoded data (non-interleaved).
  *)
val decode : t -> string -> int -> int -> int * (float array array)

(** Heuristic guess of the offset of the begining of a frame. *)
val find_frame : string -> int

module Mp4 :
sig
  type decoder = t

  (** An MP4 reader. *)
  type t

  (** A track number. *)
  type track = int

  (** A sample number. *)
  type sample = int

  (** Detect whether the file is an MP4 given at least 8 bytes of its header. *)
  val is_mp4 : string -> bool

  (** Open an MP4 file. *)
  val openfile : ?write:(string -> int) -> ?seek:(int -> int) -> ?trunc:(unit -> int) -> (int -> (string * int * int)) -> t

  (** Total number of tracks. *)
  val tracks : t -> int

  (** Find the first AAC track. *)
  val find_aac_track : t -> track

  (** Initialize a decoder. *)
  val init : t -> decoder -> track -> int * int
end
