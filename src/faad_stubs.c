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
#include <stdio.h>

#include <neaacdec.h>
#include <mp4ff.h>

static void check_err(int n)
{
  if (n < 0)
    caml_raise_constant(*caml_named_value("ocaml_faad_exn_failed"));
}

#define Dec_val(v) ((NeAACDecHandle)v)

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
  NeAACDecClose(Dec_val(dh));

  return Val_unit;
}

CAMLprim value ocaml_faad_init(value dh, value buf, value ofs, value len)
{
  u_int32_t samplerate;
  u_int8_t channels;
  int32_t ret;
  value ans;

  ret = NeAACDecInit(Dec_val(dh), (unsigned char*)String_val(buf)+Int_val(ofs), Int_val(len), &samplerate, &channels);
  check_err(ret);

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

  ret = NeAACDecInit2(Dec_val(dh), (unsigned char*)String_val(buf)+Int_val(ofs), Int_val(len), &samplerate, &channels);
  check_err(ret);

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
  data = NeAACDecDecode(Dec_val(dh), &frameInfo, inbuf, inbuflen);
  caml_leave_blocking_section();
  if (!data)
  {
    free(inbuf);
    caml_raise_constant(*caml_named_value("ocaml_faad_exn_failed"));
  }

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

/***** MP4 *****/

typedef struct
{
  mp4ff_t *ff;
  mp4ff_callback_t ff_cb;
  value read_cb;
  value write_cb;
  value seek_cb;
  value trunc_cb;
} mp4_t;

#define Mp4_val(v) (*((mp4_t**)Data_custom_val(v)))

static void finalize_mp4(value e)
{
  mp4_t *mp = Mp4_val(e);

  if (mp->ff)
    mp4ff_close(mp->ff);
  if (mp->read_cb)
    caml_remove_generational_global_root(&mp->read_cb);
  if (mp->write_cb)
    caml_remove_generational_global_root(&mp->write_cb);
  if (mp->seek_cb)
    caml_remove_generational_global_root(&mp->seek_cb);
  if (mp->trunc_cb)
    caml_remove_generational_global_root(&mp->trunc_cb);

  free(mp);
}

static struct custom_operations mp4_ops =
{
  "ocaml_mp4_t",
  finalize_mp4,
  custom_compare_default,
  custom_hash_default,
  custom_serialize_default,
  custom_deserialize_default
};

static uint32_t read_cb(void *user_data, void *buffer, uint32_t length)
{
  mp4_t *mp = (mp4_t*)user_data;
  value ans;
  int ofs, len;

  ans = caml_callback(mp->read_cb, Val_int(length));
  ofs = Int_val(Field(ans, 1));
  len = Int_val(Field(ans, 2));
  ans = Field(ans, 0);
  memcpy(buffer, String_val(ans)+ofs, len);

  return len;
}

static uint32_t write_cb(void *user_data, void *buffer, uint32_t length)
{
  //mp4_t *mp = (mp4_t*)user_data;

  return 0;
}

static uint32_t seek_cb(void *user_data, uint64_t position)
{
  mp4_t *mp = (mp4_t*)user_data;
  value ans;
  int pos;

  printf("SEEK: %llu\n", position);

  ans = caml_callback(mp->seek_cb, Val_int(position));

  pos = Int_val(ans);

  return pos;
}

static uint32_t trunc_cb(void *user_data)
{
  //mp4_t *mp = (mp4_t*)user_data;

  return 0;
}

CAMLprim value ocaml_faad_mp4_open_read(value metaonly, value read, value write, value seek, value trunc)
{
  CAMLparam4(read, write, seek, trunc);
  CAMLlocal1(ans);

  mp4_t *mp = malloc(sizeof(mp4_t));
  mp->ff_cb.read = read_cb;
  mp->read_cb = read;
  caml_register_generational_global_root(&mp->read_cb);
  if (Is_block(write))
  {
    mp->ff_cb.write = write_cb;
    mp->write_cb =  Field(write, 0);
    caml_register_generational_global_root(&mp->write_cb);
  }
  else
  {
    mp->ff_cb.write = NULL;
    mp->write_cb = 0;
  }
  if (Is_block(seek))
  {
    mp->ff_cb.seek = seek_cb;
    mp->seek_cb = Field(seek, 0);
    caml_register_generational_global_root(&mp->seek_cb);
  }
  else
  {
    mp->ff_cb.seek = NULL;
    mp->seek_cb = 0;
  }
  if (Is_block(trunc))
  {
    mp->ff_cb.truncate = trunc_cb;
    mp->trunc_cb = Field(trunc, 0);
    caml_register_generational_global_root(&mp->trunc_cb);
  }
  else
  {
    mp->ff_cb.truncate = NULL;
    mp->trunc_cb = 0;
  }
  mp->ff_cb.user_data = mp;

  if(Bool_val(metaonly))
    mp->ff = mp4ff_open_read_metaonly(&mp->ff_cb);
  else
    mp->ff = mp4ff_open_read(&mp->ff_cb);
  assert(mp->ff);

  ans = caml_alloc_custom(&mp4_ops, sizeof(mp4_t*), 1, 0);
  Mp4_val(ans) = mp;

  CAMLreturn(ans);
}

CAMLprim value ocaml_faad_mp4_total_tracks(value m)
{
  CAMLparam1(m);
  mp4_t *mp = Mp4_val(m);
  int n;

  n = mp4ff_total_tracks(mp->ff);

  CAMLreturn(Val_int(n));
}

CAMLprim value ocaml_faad_mp4_find_aac_track(value m)
{
  CAMLparam1(m);
  mp4_t *mp = Mp4_val(m);

  int i, rc;
  int num_tracks = mp4ff_total_tracks(mp->ff);

  for (i = 0; i < num_tracks; i++) {
    unsigned char *buff = NULL;
    unsigned int buff_size = 0;
    mp4AudioSpecificConfig mp4ASC;

    mp4ff_get_decoder_config(mp->ff, i, &buff, &buff_size);

    if (buff)
    {
      rc = NeAACDecAudioSpecificConfig(buff, buff_size, &mp4ASC);
      free(buff);
      if (rc < 0)
        continue;
      CAMLreturn(Val_int(i));
    }
  }

  caml_raise_constant(*caml_named_value("ocaml_faad_exn_failed"));
}

CAMLprim value ocaml_faad_mp4_init(value m, value dec, value track)
{
  CAMLparam2(m, track);
  CAMLlocal1(ans);
  mp4_t *mp = Mp4_val(m);
  int t = Int_val(track);
  int ret;
  unsigned int samplerate;
  unsigned char channels;

  unsigned char *mp4_buffer = NULL;
  unsigned int mp4_buffer_size = 0;

  mp4ff_get_decoder_config(mp->ff, t, &mp4_buffer, &mp4_buffer_size);
  ret = NeAACDecInit2(Dec_val(dec), mp4_buffer, mp4_buffer_size, &samplerate, &channels);
  check_err(ret);

  ans = caml_alloc_tuple(2);
  Store_field(ans, 0, Val_int(samplerate));
  Store_field(ans, 1, Val_int(channels));

  CAMLreturn(ans);
}

/*
file_time = mp4ff_get_track_duration_use_offsets(mp4fh, track);
	scale = mp4ff_time_scale(mp4fh, track);
*/

CAMLprim value ocaml_faad_mp4_num_samples(value m, value track)
{
  CAMLparam2(m, track);
  mp4_t *mp = Mp4_val(m);
  int t = Int_val(track);
  int ans;

  ans = mp4ff_num_samples(mp->ff, t);

  CAMLreturn(Val_int(ans));
}

CAMLprim value ocaml_faad_mp4_get_sample_duration(value m, value track, value sample)
{
  CAMLparam3(m, track, sample);
  mp4_t *mp = Mp4_val(m);
  int t = Int_val(track);
  int s = Int_val(sample);
  int ans;

  ans = mp4ff_get_sample_duration(mp->ff, t, s);

  CAMLreturn(Val_int(ans));
}

CAMLprim value ocaml_faad_mp4_get_sample_offset(value m, value track, value sample)
{
  CAMLparam3(m, track, sample);
  mp4_t *mp = Mp4_val(m);
  int t = Int_val(track);
  int s = Int_val(sample);
  int ans;

  ans = mp4ff_get_sample_offset(mp->ff, t, s);

  CAMLreturn(Val_int(ans));
}

CAMLprim value ocaml_faad_mp4_read_sample(value m, value track, value sample)
{
  CAMLparam3(m, track, sample);
  CAMLlocal1(ans);
  mp4_t *mp = Mp4_val(m);
  int t = Int_val(track);
  int s = Int_val(sample);
  unsigned char *buf;
  unsigned int buflen;
  int ret;

  ret = mp4ff_read_sample(mp->ff, t, s, &buf, &buflen);
  check_err(ret);

  ans = caml_alloc_string(buflen);
  memcpy(String_val(ans), buf, buflen);
  free(buf);

  CAMLreturn(ans);
}
