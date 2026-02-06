package main

import (
	"io"
	"net/http"

	"github.com/gin-gonic/gin"
)

func main() {
	gin.SetMode(gin.ReleaseMode)
	gin.DefaultWriter = io.Discard
	gin.DefaultErrorWriter = io.Discard

	router := gin.New()

	router.GET("/noop", func(c *gin.Context) {
		c.Status(http.StatusNoContent)
	})

	router.GET("/plaintext", func(c *gin.Context) {
		c.Data(http.StatusOK, "text/plain; charset=utf-8", []byte("Hello, World!"))
	})

	if err := router.Run("0.0.0.0:8080"); err != nil {
		panic(err)
	}
}
