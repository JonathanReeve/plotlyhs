{-# LANGUAGE OverloadedStrings #-}
module Dampf.Nginx.Types
  ( Server(..)
  , ServerDecl(..)
  , pShowServer
  , pShowFakeServer
  ) where

import           Data.Text          (Text)
import qualified Data.Text as T
import           Text.PrettyPrint


newtype Server = Server [ServerDecl] 

addDecl :: ServerDecl -> Server -> Server
addDecl d (Server ds) = Server (d : ds)

data ServerDecl
    = Listen Int [String]
    | ServerName [Text]
    | Location Text [(Text, Text)]
    | Include FilePath
    | SSLCertificate FilePath
    | SSLCertificateKey FilePath
    | SSLTrustedCertificate FilePath
    | Return Int String


pShowServer :: Server -> String
pShowServer = render . pprServer

pShowFakeServer :: Server -> String
pShowFakeServer = render . addMoreThings 
  where addMoreThings doc = 
              text "events" <+> lbrace
          $+$ nest 4 (text "worker_connections 512;") 
          $+$ rbrace
          $+$ text "http" <+> lbrace
          $+$ nest 4 (pprServer doc)
          $+$ rbrace

pprServer :: Server -> Doc
pprServer (Server ds) = 
      text "server" <+> lbrace
  $+$ nest 4 (vcat $ fmap pprServerDecl ds)
  $+$ rbrace

pprServerDecl :: ServerDecl -> Doc
pprServerDecl (Listen p ss)         = text "listen"
    <+> int p <+> vcat (fmap text ss) <> semi

pprServerDecl (ServerName ns)       = text "server_name"
    <+> hsep (fmap (text . T.unpack) ns) <> semi

pprServerDecl (Location p kvs)      = text "location"
    <+> text (T.unpack p) <+> lbrace
    $+$ nest 4 (vcat (fmap ppMap kvs))
    $+$ rbrace

pprServerDecl (Include p)           = text "include"
    <+> text p <> semi

pprServerDecl (SSLCertificate p)    = text "ssl_certificate"
    <+> text p <> semi

pprServerDecl (SSLTrustedCertificate p)    = text "ssl_trusted_certificate"
    <+> text p <> semi


pprServerDecl (SSLCertificateKey p) = text "ssl_certificate_key"
    <+> text p <> semi

pprServerDecl (Return i url) = text "return" 
    <+> int i <+> text url

ppMap :: (Text, Text) -> Doc
ppMap (k, v) = text (T.unpack k) <+> text (T.unpack v) <> semi
