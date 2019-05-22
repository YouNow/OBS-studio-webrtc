#include "WebsocketClient.h"

//Use http://think-async.com/ insted of boost
#define ASIO_STANDALONE
#define _WEBSOCKETPP_CPP11_STL_
#define _WEBSOCKETPP_CPP11_THREAD_
#define _WEBSOCKETPP_CPP11_FUNCTIONAL_
#define _WEBSOCKETPP_CPP11_SYSTEM_ERROR_
#define _WEBSOCKETPP_CPP11_RANDOM_DEVICE_
#define _WEBSOCKETPP_CPP11_MEMORY_

#include "websocketpp/config/asio_client.hpp"
#include "websocketpp/client.hpp"

#include "obs.h"


#define warn(format, ...)  blog(LOG_WARNING, format, ##__VA_ARGS__)
#define info(format, ...)  blog(LOG_INFO,    format, ##__VA_ARGS__)
#define debug(format, ...) blog(LOG_DEBUG,   format, ##__VA_ARGS__)
#define error(format, ...) blog(LOG_ERROR,   format, ##__VA_ARGS__)

typedef websocketpp::client<websocketpp::config::asio_tls_client> Client;

class YouNowWebsocketClientImpl : public WebsocketClient
{
public:
    YouNowWebsocketClientImpl();
    ~YouNowWebsocketClientImpl();
    virtual bool connect(std::string url, long long room, std::string username, std::string token, WebsocketClient::Listener* listener);
    virtual bool open(const std::string &sdp, const bool isJoin, const int maxBw);
    virtual bool trickle(const std::string &mid, int index, const std::string &candidate, bool last);
    virtual bool disconnect(bool wait);

private:
    bool logged;
    std::string token;
    long long handle_id;

    std::atomic<bool> is_running;
    std::future<void> handle;
    std::thread thread;
   
    Client client;
    Client::connection_ptr connection;

    std::string peerId;
    std::string userId;
    std::string roomId;
    std::string streamKey;
    std::string authKey;

    std::string CreateRandomString(size_t length);
    
};

