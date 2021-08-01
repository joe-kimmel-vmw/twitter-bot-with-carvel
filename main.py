import os
import random

import tweepy

def tweet():
  return random.choice([
    "Help I'm a bot",
    "tweet. tweet. twiddly tweet",
    "Pleased to tweet you",
    "Do twitbots dream of electic birds?"
  ])


# Authenticate to Twitter
auth = tweepy.OAuthHandler(os.getenv("TWIT_CONSUMER_KEY"), os.getenv("TWIT_CONSUMER_SECRET"))
auth.set_access_token(os.getenv("TWIT_ACCESS_TOKEN"), os.getenv("TWIT_ACCESS_TOKEN_SECRET"))

# Create API object
api = tweepy.API(auth)

# Create a tweet
api.update_status(tweet())

