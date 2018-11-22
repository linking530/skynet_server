#!/bin/bash

# 生成协议
protoc -o ./res/talkbox.pb ./res/talkbox.proto
protoc -o ./res/login.pb ./res/login.proto
protoc -o ./res/game.pb ./res/game.proto
protoc -o ./res/users.pb ./res/users.proto

protoc -o ./res/addressbook.pb ./res/addressbook.proto
protoc -o ./res/descriptor.pb ./res/descriptor.proto
protoc -o ./res/float.pb ./res/float.proto
protoc -o ./res/test.pb ./res/test.proto