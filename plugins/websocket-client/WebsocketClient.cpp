#include <obs-module.h>
#include <openssl/opensslv.h>
#include "YouNowWebsocketClientImpl.h"

OBS_DECLARE_MODULE()

bool obs_module_load(void)
{
  OPENSSL_init_ssl(0, NULL);
  return true;
}

WEBSOCKETCLIENT_API WebsocketClient* createWebsocketClient(int type)
{
	if (type == WEBSOCKETCLIENT_YOUNOW) {
		std::cout << "WebsocketClient: YOUNOW";
		return new YouNowWebsocketClientImpl();
	}
	else {
		std::cout << "WebsocketClient: NULL";
	}
  return nullptr;
}
