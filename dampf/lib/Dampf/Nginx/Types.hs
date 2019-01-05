{-# LANGUAGE OverloadedStrings #-}
module Dampf.Nginx.Types
  ( Server(..)
  , ServerDecl(..)
  , pShowServers
  , pShowTestServers
  , IsTest
  , IsSSL
  , IsHttpsOnly
  ) where

import           Data.Text          (Text)
import qualified Data.Text as T
import           Text.PrettyPrint

newtype Server = Server [ServerDecl] 

data ServerDecl
    = Listen Int [String]
    | ServerName [Text]
    | Location Text [(Text, Text)]
    | Include FilePath
    | SSLCertificate FilePath
    | SSLCertificateKey FilePath
    | SSLTrustedCertificate FilePath
    | Return Int String
    | Resolver String


type IsTest = Bool
type IsHttpsOnly = Bool
type IsSSL = Bool


defaultNginxConf :: Doc -> Doc
defaultNginxConf doc = 
      text "events" <+> lbrace
  $+$ nest 4 (text "worker_connections 512;") 
  $+$ rbrace
  $+$ text "http" <+> lbrace
  $+$ nest 4 
          (
              text "log_format default"
              <+>  "'$sent_http_Host'; "
          $+$ text "access_log"
              <+>  "/etc/nginx/logs/dampf-nginx-access.log;"
          $+$ text "error_log"
              <+>  "/etc/nginx/logs/dampf-nginx-error.log"
              <+>  "warn;"
          $+$ doc
          )
  $+$ rbrace


pShowTestServers :: [Server] -> String
pShowTestServers = 
  render . defaultNginxConf . vcat . map pprServer


pShowServers :: [Server] -> String
pShowServers = 
  render . vcat . map pprServer


pprServer :: Server -> Doc
pprServer (Server ds) = 
      text "server" <+> lbrace
  $+$ nest 4 (vcat $ fmap pprServerDecl ds)
  $+$ rbrace

pprServerDecl :: ServerDecl -> Doc
pprServerDecl (Listen p ss) = 
  text "listen"
  <+> int p <+> vcat (fmap text ss) <> semi

pprServerDecl (ServerName ns) = 
  text "server_name"
  <+> hsep (fmap (text . T.unpack) ns) <> semi

pprServerDecl (Location p kvs) =
  text "location"
  <+> text (T.unpack p) <+> lbrace
  $+$ nest 4 (vcat (fmap ppMap kvs))
  $+$ rbrace

pprServerDecl (Include p) = 
  text "include"
  <+> text p <> semi

pprServerDecl (SSLCertificate p) = 
  text "ssl_certificate"
  <+> text p <> semi

pprServerDecl (SSLTrustedCertificate p) = 
  text "ssl_trusted_certificate"
  <+> text p <> semi


pprServerDecl (SSLCertificateKey p) = 
  text "ssl_certificate_key"
  <+> text p <> semi

pprServerDecl (Return i url) = 
  text "return" 
  <+> int i <+> text url <> semi

pprServerDecl (Resolver ip) = text "resolver" <+> text ip <> semi

ppMap :: (Text, Text) -> Doc
ppMap (k, v) = text (T.unpack k) <+> text (T.unpack v) <> semi
