#include <obs-module.h>

struct younow {
  char *server, *milli_id, *codec, *token;
};

static const char *younow_name(void *unused)
{
  UNUSED_PARAMETER(unused);
  return obs_module_text("YouNow");
}

static void younow_update(void *data, obs_data_t *settings)
{
  struct younow *service = data;

  bfree(service->server);
  bfree(service->milli_id);
  bfree(service->codec);
  bfree(service->token);

  service->server   = bstrdup(obs_data_get_string(settings, "server"  ));
  service->milli_id = bstrdup(obs_data_get_string(settings, "milli_id"));
  service->token    = bstrdup(obs_data_get_string(settings, "token"));
  service->codec    = bstrdup(obs_data_get_string(settings, "codec"   ));

}

static void younow_destroy(void *data)
{
  struct younow *service = data;

  bfree(service->server  );
  bfree(service->milli_id);
  bfree(service->codec   );
  bfree(service->token   );
  bfree(service          );
}

static void *younow_create(obs_data_t *settings, obs_service_t *service)
{
  struct younow *data = bzalloc(sizeof(struct younow));
  younow_update(data, settings);

  UNUSED_PARAMETER(service);
  return data;
}

static obs_properties_t *younow_properties(void *unused)
{
  UNUSED_PARAMETER(unused);

  obs_properties_t *ppts = obs_properties_create();
  obs_properties_add_text(ppts, "token", obs_module_text("Stream Key"), OBS_TEXT_PASSWORD);
  
  return ppts;
}

static const char *younow_url(void *data)
{
  struct younow *service = data;
  return service->server;
}

static const char *younow_id(void *data)
{
  struct younow *service = data;
  return service->milli_id;
}

static const char *younow_codec(void *data)
{
  struct younow *service = data;
  return service->codec;
}

static const char *younow_token(void *data)
{
  struct younow *service = data;
  return service->token;
}
static const char *younow_room(void *data)
{
  return "1";
}

struct obs_service_info younow_service = {
  .id              = "younow",
  .get_name        = younow_name,
  .create          = younow_create,
  .destroy         = younow_destroy,
  .update          = younow_update,
  .get_properties  = younow_properties,
  .get_url         = younow_url,
  .get_milli_id    = younow_id,
  .get_codec       = younow_codec,
  .get_milli_token = younow_token,
  .get_room        = younow_room
};
