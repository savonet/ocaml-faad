/*
 * Copyright (C) 2003-2008 Samuel Mimram
 *
 * This file is part of Ocaml-faad.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 */

/**
 * Libfaad bindings for OCaml.
 *
 * @author Samuel Mimram
 */


#include <caml/alloc.h>
#include <caml/callback.h>
#include <caml/custom.h>
#include <caml/fail.h>
#include <caml/memory.h>
#include <caml/mlvalues.h>
#include <caml/signals.h>

#include <sys/types.h>
#include <string.h>
#include <assert.h>

#include <neaacdec.h>

CAMLprim value ocaml_faad_open(value unit)
{
  NeAACDecHandle dh = NeAACDecOpen();
  NeAACDecConfigurationPtr conf = NeAACDecGetCurrentConfiguration(dh);

  conf->outputFormat = FAAD_FMT_FLOAT;
  NeAACDecSetConfiguration(dh, conf);

  return (value)dh;
}

CAMLprim value ocaml_faad_close(value dh)
{
  NeAACDecClose((NeAACDecHandle)dh);

  return Val_unit;
}

CAMLprim value ocaml_faad_init(value dh, value buf, value ofs, value len)
{
  u_int32_t samplerate;
  u_int8_t channels;
  int32_t ret;
  value ans;

  ret = NeAACDecInit((NeAACDecHandle)dh, (unsigned char*)String_val(buf)+Int_val(ofs), Int_val(len), &samplerate, &channels);

  ans = caml_alloc_tuple(3);
  Store_field(ans, 0, Val_int(ret));
  Store_field(ans, 1, Val_int(samplerate));
  Store_field(ans, 2, Val_int(channels));
  return ans;
}

CAMLprim value ocaml_faad_init2(value dh, value buf, value ofs, value len)
{
  u_int32_t samplerate;
  u_int8_t channels;
  int8_t ret;
  value ans;

  ret = NeAACDecInit2((NeAACDecHandle)dh, (unsigned char*)String_val(buf)+Int_val(ofs), Int_val(len), &samplerate, &channels);

  ans = caml_alloc_tuple(2);
  Store_field(ans, 0, Val_int(samplerate));
  Store_field(ans, 1, Val_int(channels));
  return ans;
}

CAMLprim value ocaml_faad_decode(value dh, value _inbuf, value _inbufofs, value _inbuflen)
{
  CAMLparam1(_inbuf);
  CAMLlocal2(ans, outbuf);
  NeAACDecFrameInfo frameInfo;
  int inbufofs = Int_val(_inbufofs);
  int inbuflen = Int_val(_inbuflen);
  unsigned char *inbuf = malloc(inbuflen);
  float *data;
  int c, i;

  memcpy(inbuf, String_val(_inbuf)+inbufofs, inbuflen);

  caml_enter_blocking_section();
  data = NeAACDecDecode((NeAACDecHandle)dh, &frameInfo, inbuf, inbuflen);
  caml_leave_blocking_section();

  if (frameInfo.error != 0)
    caml_raise_with_arg(*caml_named_value("ocaml_faad_exn_error"), Val_int(frameInfo.error));

  outbuf = caml_alloc_tuple(frameInfo.channels);
  for(c = 0; c < frameInfo.channels; c++)
    Store_field(outbuf, c, caml_alloc(frameInfo.samples / frameInfo.channels * Double_wosize, Double_array_tag));
  for(i = 0; i < frameInfo.samples; i++)
    Store_double_field(Field(outbuf, i % frameInfo.channels), i / frameInfo.channels, data[i]);

  ans = caml_alloc_tuple(2);
  Store_field(ans, 0, Val_int(frameInfo.bytesconsumed));
  Store_field(ans, 1, outbuf);

  CAMLreturn(ans);
}

CAMLprim value ocaml_faad_get_error_message(value err)
{
  return caml_copy_string((char*)NeAACDecGetErrorMessage(Int_val(err)));
}
