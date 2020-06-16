#include <mutex>

#include "TgVoip.h"

#include "rtc_base/logging.h"

#include "Manager.h"

#include <stdarg.h>
#include <iostream>

#import <Foundation/Foundation.h>

#ifndef TGVOIP_USE_CUSTOM_CRYPTO
/*extern "C" {
#include <openssl/sha.h>
#include <openssl/aes.h>
#include <openssl/modes.h>
#include <openssl/rand.h>
#include <openssl/crypto.h>
}

static void tgvoip_openssl_aes_ige_encrypt(uint8_t* in, uint8_t* out, size_t length, uint8_t* key, uint8_t* iv){
    AES_KEY akey;
    AES_set_encrypt_key(key, 32*8, &akey);
    AES_ige_encrypt(in, out, length, &akey, iv, AES_ENCRYPT);
}

static void tgvoip_openssl_aes_ige_decrypt(uint8_t* in, uint8_t* out, size_t length, uint8_t* key, uint8_t* iv){
    AES_KEY akey;
    AES_set_decrypt_key(key, 32*8, &akey);
    AES_ige_encrypt(in, out, length, &akey, iv, AES_DECRYPT);
}

static void tgvoip_openssl_rand_bytes(uint8_t* buffer, size_t len){
    RAND_bytes(buffer, (int)len);
}

static void tgvoip_openssl_sha1(uint8_t* msg, size_t len, uint8_t* output){
    SHA1(msg, len, output);
}

static void tgvoip_openssl_sha256(uint8_t* msg, size_t len, uint8_t* output){
    SHA256(msg, len, output);
}

static void tgvoip_openssl_aes_ctr_encrypt(uint8_t* inout, size_t length, uint8_t* key, uint8_t* iv, uint8_t* ecount, uint32_t* num){
    AES_KEY akey;
    AES_set_encrypt_key(key, 32*8, &akey);
    CRYPTO_ctr128_encrypt(inout, inout, length, &akey, iv, ecount, num, (block128_f) AES_encrypt);
}

static void tgvoip_openssl_aes_cbc_encrypt(uint8_t* in, uint8_t* out, size_t length, uint8_t* key, uint8_t* iv){
    AES_KEY akey;
    AES_set_encrypt_key(key, 256, &akey);
    AES_cbc_encrypt(in, out, length, &akey, iv, AES_ENCRYPT);
}

static void tgvoip_openssl_aes_cbc_decrypt(uint8_t* in, uint8_t* out, size_t length, uint8_t* key, uint8_t* iv){
    AES_KEY akey;
    AES_set_decrypt_key(key, 256, &akey);
    AES_cbc_encrypt(in, out, length, &akey, iv, AES_DECRYPT);
}

CryptoFunctions Layer92::crypto={
        tgvoip_openssl_rand_bytes,
        tgvoip_openssl_sha1,
        tgvoip_openssl_sha256,
        tgvoip_openssl_aes_ige_encrypt,
        tgvoip_openssl_aes_ige_decrypt,
        tgvoip_openssl_aes_ctr_encrypt,
        tgvoip_openssl_aes_cbc_encrypt,
        tgvoip_openssl_aes_cbc_decrypt
};*/
#endif


#ifdef TGVOIP_NAMESPACE
namespace TGVOIP_NAMESPACE {
#endif

class TgVoipImpl : public TgVoip, public sigslot::has_slots<> {
public:
    TgVoipImpl(
            std::vector<TgVoipEndpoint> const &endpoints,
            TgVoipPersistentState const &persistentState,
            std::unique_ptr<TgVoipProxy> const &proxy,
            TgVoipConfig const &config,
            TgVoipEncryptionKey const &encryptionKey,
            TgVoipNetworkType initialNetworkType,
            std::function<void(TgVoipState)> stateUpdated,
            std::function<void(const std::vector<uint8_t> &)> signalingDataEmitted
    ) :
    _stateUpdated(stateUpdated),
    _signalingDataEmitted(signalingDataEmitted) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            rtc::LogMessage::LogToDebug(rtc::LS_INFO);
            rtc::LogMessage::SetLogToStderr(true);
        });
        
        _managerThread = rtc::Thread::Create();
        _managerThread->Start();
        _manager.reset(new ThreadLocalObject<Manager>(_managerThread.get(), [managerThreadPtr = _managerThread.get(), encryptionKey = encryptionKey, stateUpdated, signalingDataEmitted](){
            return new Manager(
                managerThreadPtr,
                encryptionKey,
                [stateUpdated](const TgVoipState &state) {
                    stateUpdated(state);
                },
                [signalingDataEmitted](const std::vector<uint8_t> &data) {
                    signalingDataEmitted(data);
                }
            );
        }));
        _manager->perform([](Manager *manager) {
            manager->start();
        });
    }

    ~TgVoipImpl() override {
    }
    
    void receiveSignalingData(const std::vector<uint8_t> &data) override {
        _manager->perform([data](Manager *manager) {
            manager->receiveSignalingData(data);
        });
    };

    void setNetworkType(TgVoipNetworkType networkType) override {
        /*message::NetworkType mappedType;

        switch (networkType) {
            case TgVoipNetworkType::Unknown:
                mappedType = message::NetworkType::nUnknown;
                break;
            case TgVoipNetworkType::Gprs:
                mappedType = message::NetworkType::nGprs;
                break;
            case TgVoipNetworkType::Edge:
                mappedType = message::NetworkType::nEdge;
                break;
            case TgVoipNetworkType::ThirdGeneration:
                mappedType = message::NetworkType::n3gOrAbove;
                break;
            case TgVoipNetworkType::Hspa:
                mappedType = message::NetworkType::n3gOrAbove;
                break;
            case TgVoipNetworkType::Lte:
                mappedType = message::NetworkType::n3gOrAbove;
                break;
            case TgVoipNetworkType::WiFi:
                mappedType = message::NetworkType::nHighSpeed;
                break;
            case TgVoipNetworkType::Ethernet:
                mappedType = message::NetworkType::nHighSpeed;
                break;
            case TgVoipNetworkType::OtherHighSpeed:
                mappedType = message::NetworkType::nHighSpeed;
                break;
            case TgVoipNetworkType::OtherLowSpeed:
                mappedType = message::NetworkType::nEdge;
                break;
            case TgVoipNetworkType::OtherMobile:
                mappedType = message::NetworkType::n3gOrAbove;
                break;
            case TgVoipNetworkType::Dialup:
                mappedType = message::NetworkType::nGprs;
                break;
            default:
                mappedType = message::NetworkType::nUnknown;
                break;
        }

        controller_->SetNetworkType(mappedType);*/
    }

    void setMuteMicrophone(bool muteMicrophone) override {
        //controller_->SetMute(muteMicrophone);
    }
    
    void setIncomingVideoOutput(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink) {
        _manager->perform([sink](Manager *manager) {
            manager->setIncomingVideoOutput(sink);
        });
    }
    
    void setOutgoingVideoOutput(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink) {
        _manager->perform([sink](Manager *manager) {
            manager->setOutgoingVideoOutput(sink);
        });
    }

    void setAudioOutputGainControlEnabled(bool enabled) override {
    }

    void setEchoCancellationStrength(int strength) override {
    }

    std::string getLastError() override {
        return "";  // TODO: not implemented
    }

    std::string getDebugInfo() override {
        return "";  // TODO: not implemented
    }

    int64_t getPreferredRelayId() override {
        return 0;  // we don't have endpoint ids
    }

    TgVoipTrafficStats getTrafficStats() override {
        return TgVoipTrafficStats{};  // TODO: not implemented
    }

    TgVoipPersistentState getPersistentState() override {
        return TgVoipPersistentState{};  // we dont't have such information
    }

    TgVoipFinalState stop() override {
        TgVoipFinalState finalState = {
        };

        return finalState;
    }

    /*void controllerStateCallback(Controller::State state) {
        if (onStateUpdated_) {
            TgVoipState mappedState;
            switch (state) {
                case Controller::State::WaitInit:
                    mappedState = TgVoipState::WaitInit;
                    break;
                case Controller::State::WaitInitAck:
                    mappedState = TgVoipState::WaitInitAck;
                    break;
                case Controller::State::Established:
                    mappedState = TgVoipState::Estabilished;
                    break;
                case Controller::State::Failed:
                    mappedState = TgVoipState::Failed;
                    break;
                case Controller::State::Reconnecting:
                    mappedState = TgVoipState::Reconnecting;
                    break;
                default:
                    mappedState = TgVoipState::Estabilished;
                    break;
            }

            onStateUpdated_(mappedState);
        }
    }*/

private:
    std::unique_ptr<rtc::Thread> _managerThread;
    std::unique_ptr<ThreadLocalObject<Manager>> _manager;
    std::function<void(TgVoipState)> _stateUpdated;
    std::function<void(const std::vector<uint8_t> &)> _signalingDataEmitted;
};

std::function<void(std::string const &)> globalLoggingFunction;

void __tgvoip_call_tglog(const char *format, ...){
    va_list vaArgs;
    va_start(vaArgs, format);

    va_list vaCopy;
    va_copy(vaCopy, vaArgs);
    const int length = std::vsnprintf(nullptr, 0, format, vaCopy);
    va_end(vaCopy);

    std::vector<char> zc(length + 1);
    std::vsnprintf(zc.data(), zc.size(), format, vaArgs);
    va_end(vaArgs);

    if (globalLoggingFunction != nullptr) {
        globalLoggingFunction(std::string(zc.data(), zc.size()));
    }
}

void TgVoip::setLoggingFunction(std::function<void(std::string const &)> loggingFunction) {
    globalLoggingFunction = loggingFunction;
}

void TgVoip::setGlobalServerConfig(const std::string &serverConfig) {
}

int TgVoip::getConnectionMaxLayer() {
    return 92;  // TODO: retrieve from LayerBase
}

std::string TgVoip::getVersion() {
    return "";  // TODO: version not known while not released
}

TgVoip *TgVoip::makeInstance(
        TgVoipConfig const &config,
        TgVoipPersistentState const &persistentState,
        std::vector<TgVoipEndpoint> const &endpoints,
        std::unique_ptr<TgVoipProxy> const &proxy,
        TgVoipNetworkType initialNetworkType,
        TgVoipEncryptionKey const &encryptionKey,
        std::function<void(TgVoipState)> stateUpdated,
        std::function<void(const std::vector<uint8_t> &)> signalingDataEmitted
) {
    return new TgVoipImpl(
            endpoints,
            persistentState,
            proxy,
            config,
            encryptionKey,
            initialNetworkType,
            stateUpdated,
            signalingDataEmitted
    );
}

TgVoip::~TgVoip() = default;

#ifdef TGVOIP_NAMESPACE
}
#endif
