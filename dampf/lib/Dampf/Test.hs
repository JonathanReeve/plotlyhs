{-# language TupleSections #-}
{-# language BangPatterns #-}
{-# language LambdaCase #-}
{-# language OverloadedStrings #-}
{-# language ViewPatterns #-}
{-# language FlexibleContexts #-}

module Dampf.Test where

import Dampf.Types
import Dampf.Monitor
import Dampf.Docker.Free
import Dampf.Docker.Types
import Dampf.Docker.Args.Run
import Dampf.Nginx (pretendToDeployDomains)

import Data.Text (Text)
import Data.Map (Map)
import Data.Monoid ((<>))

import System.Random
import System.Directory

import Control.Lens 
import Control.Monad 
import Control.Monad.Reader
import Control.Monad.Catch (MonadCatch, onException)
import Control.Monad.IO.Class (MonadIO, liftIO)

import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import qualified Data.Text.IO as T

type Network = Text
type Volumes = Map FilePath FilePath 
type ContainerNames = [Text]
type Names = [Text]

test :: (MonadCatch m, MonadIO m) => Tests -> DampfT m ()
test ls = do
  netName <- randomName
  proxies <- ask <&> toListOf 
    (app.domains.traversed.proxyContainer._Just.to 
      (head . T.splitOn ":"))
  
  test_containers <- tests_to_run ls 

  let 
    testContainerNames = 
      toListOf 
        (traversed.tsUnits.traversed.traverseTestRunImageName) 
        test_containers

    containerMess = 
      nginx_container_name : proxies ++ testContainerNames

    onlyProxyContainers = app.containers.to 
      (Map.filter (^. image.to (flip elem proxies)))

  void . runDockerT $ do
    netCreate netName

    view onlyProxyContainers >>= imapM_ (runWith (set net netName))

    nginx_ip <- pretendToDeployDomains >>= runNginx netName

    fakeHosts <- set mapped nginx_ip <$> view (app . domains)
    pushHostsFile fakeHosts

    let runArgsTweak =  set net netName 
                      . set detach (Detach False)
                      . set hosts fakeHosts

    runTests runArgsTweak test_containers

    stopMany containerMess
    void (rmMany containerMess)
    void (netRM [netName])
    popHostsFile

nginx_container_name :: Text
nginx_container_name = "dampf-nginx"


pushHostsFile 
  :: (MonadIO m, MonadCatch m)
  => Map Text IP
  -> m ()

pushHostsFile mhosts = 
  let
    (<+>) !a !b = a <> " " <> b 

    mkfile = T.unwords . fst . Map.foldlWithKey' go ([], mempty)

    go :: ([Text], Text) -> Text -> IP -> ([Text], Text)
    go ([], _) mhost ip = (ip <+> mhost : [], ip)
    go ( (h:rest), lastIp ) mhost ip 
      | ip == lastIp  = (h <+> mhost : rest, lastIp)
      | otherwise     = (ip <+> mhost : h : rest, ip)

    push = liftIO $ do
      createDirectoryIfMissing False "/etc/hosts.d/" 
      copyFile "/etc/hosts" "/etc/hosts.d/hosts.old"

      (T.appendFile "/etc/hosts" . mkfile) mhosts

  in onException push popHostsFile


popHostsFile :: (MonadIO m, MonadCatch m) => m ()
popHostsFile = liftIO $ do
  shouldPop <- doesFileExist "/etc/hosts.d/hosts.old"
  when shouldPop $ do
    copyFile "/etc/hosts.d/hosts.old" "/etc/hosts"
    removeDirectoryRecursive "/etc/hosts.d/"


runNginx 
  :: (MonadIO m, MonadCatch m) 
  => Network 
  -> Volumes 
  -> DockerT m IP

runNginx netName vs =
  runWith xargs nginx_container_name xSpec >>= getIp . T.take 12 
    where 
      getIp (head . T.lines -> !id') = 
        head . T.lines <$> inspect 
        "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" id'

      xargs = set net netName 
            . set volumes vs 
            . set publish [Port 443, Port 80] 
            {-. set detach (Detach False)-}

      xSpec = ContainerSpec "nginx" Nothing Nothing Nothing


randomName :: MonadIO m => m Network
randomName = 
  fmap T.pack . replicateM 16 . liftIO . randomRIO $ ('a','z')
