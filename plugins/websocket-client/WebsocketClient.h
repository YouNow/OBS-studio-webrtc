#ifndef _WEBSOCKETCLIENT_H_
#define _WEBSOCKETCLIENT_H_

#ifdef _MSC_VER

#  ifdef WEBSOCKETCLIENT_EXPORTS
#    define WEBSOCKETCLIENT_API __declspec(dllexport)
#  else
#    define WEBSOCKETCLIENT_API __declspec(dllimport)
#  endif
#else
#  ifndef  __APPLE__
#    define WEBSOCKETCLIENT_API
#  else
#    define WEBSOCKETCLIENT_API __attribute__((visibility("default")))
#  endif
#endif

#include <string>

#define WEBSOCKETCLIENT_YOUNOW  3

class WEBSOCKETCLIENT_API WebsocketClient
{
public:
  class Listener
  {
  public:
    virtual void onConnected() = 0;
    virtual void onLogged(int code) = 0;
    virtual void onLoggedError(int code) = 0;
    virtual void onOpened(const std::string &sdp) = 0;
    virtual void onOpenedError(int code) = 0;
    virtual void onDisconnected() = 0;
    virtual void onIceCandidateReceived(const std::string &sdp_mid, const int sdp_midlineindex, const std::string &sdp) = 0;
  };
public:
  virtual bool connect(std::string url, long long room, std::string username, std::string token, Listener* listener) = 0;
  virtual bool open(const std::string &sdp, const bool isJoin, const int maxBw ) = 0;
  virtual bool trickle(const std::string &mid, int index, const std::string &candidate, bool last) = 0;
  virtual bool disconnect(bool wait) = 0;

};

WEBSOCKETCLIENT_API WebsocketClient* createWebsocketClient(int type);

#endif
