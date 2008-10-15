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

(** Get the error message corresponding to a raised [Error]. *)
val get_error_message : int -> string

(** Create a new decoder. *)
val create : unit -> t

(** Close a decoder. *)
val close : t -> unit

(** [init dec buf ofs len] initializes a decoder given the [len] bytes of data
  * in [buf] starting at offset [ofs]. It returns the offet, the samplerate and
  * the number of channels of the stream.
  *)
val init : t -> string -> int -> int -> int * int * int
val init2 : t -> string -> int -> int -> int * int

(** [decode dec buf ofs len] decodes at most [len] bytes of data in [buf]
  * starting at offset [ofs]. It returns the number of bytes actually decoded
  * and the decoded data (non-interleaved).
  *)
val decode : t -> string -> int -> int -> int * (float array array)

(** Heuristic guess of the offset of the begining of a frame. *)
val find_frame : string -> int
