(defpackage :lsp.client
  (:use :cl
        :lsp.protocol
        :lsp.editor))

(in-package :lsp.client)

(defparameter +port+ 10003)

(defvar *client* nil)

(macrolet ((def (name key)
             (let ((_client (gensym "CLIENT"))
                   (_value (gensym "VALUE")))
               `(progn
                  (defun ,name (,_client)
                    (getf (jsonrpc:transport-data ,_client) ,key))
                  (defun (setf ,name) (,_value ,_client)
                    (setf (getf (jsonrpc:transport-data ,_client) ,key)
                          ,_value))))))
  (def client.server-capabilities :server-capabilities))

(defun initialize ()
  (unless *client*
    (setf *client* (jsonrpc:client-connect :host "127.0.0.1" :port +port+))
    (setf (client.server-capabilities *client*)
          (jsonrpc:call *client*
                        "initialize"
                        (list
                         (convert-to-hash-table
                          (make-instance '|InitializeParams|
                                         :|processId| nil
                                         :|rootPath| nil
                                         :|rootUri| nil
                                         #+(or):|initializationOptions|
                                         :|capabilities| (make-instance
                                                          '|ClientCapabilities|
                                                          :|workspace| (make-instance
                                                                        '|WorkspaceClientCapabilites|
                                                                        :|applyEdit| t
                                                                        #+(or):|didChangeConfiguration|
                                                                        #+(or):|didChangeWatchedFiles|
                                                                        #+(or):|symbol|
                                                                        #+(or):|executeCommand|)
                                                          :|textDocument| (make-instance
                                                                           '|TextDocumentClientCapabilities|
                                                                           :|synchronization| t
                                                                           :|completion| t
                                                                           :|hover| t
                                                                           :|signatureHelp| t
                                                                           :|references| t
                                                                           :|documentHighlight| t
                                                                           :|documentSymbol| t
                                                                           :|formatting| t
                                                                           :|rangeFormatting| t
                                                                           :|onTypeFormatting| t
                                                                           :|definition| t
                                                                           :|codeAction| t
                                                                           :|codeLens| t
                                                                           :|documentLink| t
                                                                           :|rename| t)
                                                          #+(or):|experimental|)
                                         #+(or):|trace|)))))))

(defun init-hook ()
  (lem:add-hook lem:*find-file-hook* 'text-document-did-open)
  (lem:add-hook lem:*after-save-hook* 'text-document-did-save)
  (lem:add-hook lem:*kill-buffer-hook* 'text-document-did-close))

(defun text-document-did-open (buffer)
  (jsonrpc:notify *client*
                  "textDocument/didOpen"
                  (list
                   (convert-to-hash-table
                    (make-instance
                     '|DidOpenTextDocumentParams|
                     :|textDocument| (make-instance
                                      '|TextDocumentItem|
                                      :|uri| (lem-base:buffer-filename buffer)
                                      :|languageId| "common-lisp"
                                      :|version| 0
                                      :|text| (lem-base:points-to-string
                                               (lem-base:buffers-start buffer)
                                               (lem-base:buffers-end buffer))))))))

(defun text-document-did-change (buffer start end old-len)
  (jsonrpc:notify *client*
                  "textDocument/didChange"
                  (list
                   (convert-to-hash-table
                    (make-instance
                     '|DidChangeTextDocumentParams|
                     :|textDocument| (make-instance '|VersionedTextDocumentIdentifier|
                                                    :|version| (lem-base:buffer-version buffer)
                                                    :|uri| (lem-base:buffer-filename buffer))
                     :|contentChanges| (list (make-instance
                                              '|TextDocumentContentChangeEvent|
                                              :|range| (make-lsp-range start end)
                                              :|rangeLength| old-len
                                              :|text| (if (zerop old-len)
                                                          (lem-base:points-to-string start end)
                                                          ""))))))))

(defun text-document-did-save (buffer)
  (jsonrpc:notify *client*
                  "textDocument/didSave"
                  (list
                   (convert-to-hash-table
                    (make-instance
                     '|DidSaveTextDocumentParams|
                     :|textDocument| (make-instance '|TextDocumentIdentifier|
                                                    :|uri| (lem:buffer-filename buffer)))))))

(defun text-document-did-close (buffer)
  (jsonrpc:notify *client*
                  "textDocument/didClose"
                  (list
                   (convert-to-hash-table
                    (make-instance
                     '|DidCloseTextDocumentParams|
                     :|textDocument| (make-instance '|TextDocumentIdentifier|
                                                    :|uri| (lem-base:buffer-filename buffer)))))))

(defun hover (point)
  (jsonrpc:call *client*
                "textDocument/hover"
                (list
                 (convert-to-hash-table
                  (make-instance '|TextDocumentPositionParams|
                                 :|textDocument| (make-instance '|TextDocumentIdentifier|
                                                                :|uri| (lem-base:buffer-filename
                                                                        (lem-base:point-buffer point)))
                                 :|position| (make-lsp-position point))))))

(defvar buf)

(defun main ()
  (initialize)
  (setf buf (lem-base:find-file-buffer "~/tmp/test.lisp"))
  (text-document-did-open buf)
  (hover (lem-base:character-offset (lem-base:buffer-point buf) 2)))