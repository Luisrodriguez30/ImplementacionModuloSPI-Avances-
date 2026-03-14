# Descripción del Testbench

El **testbench** se utiliza para verificar el funcionamiento de la comunicación SPI entre los módulos `spi_master` y `spi_slave`. En la simulación se instancian ambos módulos y se conectan mediante las señales SPI: **SCLK, MOSI, MISO y SS**.  

También se generan las señales necesarias para la prueba, como **clk**, **rst** y **start**, que permiten iniciar las transferencias de datos y observar el comportamiento del sistema durante la simulación.

Durante la simulación se observarán las señales principales en el visor de ondas de ModelSim, verificando que:
	•	El master genere correctamente el reloj SPI (sclk).
	•	El slave responda únicamente cuando ss esté en bajo.
	•	Los datos enviados por MOSI sean correctamente recibidos por el slave.
	•	Los datos enviados por MISO sean correctamente recibidos por el master.
	•	La señal done indique correctamente el final de la transferencia.

El testbench permitirá comprobar que el desplazamiento de bits en los registros de ambos módulos funciona correctamente y que la comunicación full-duplex del protocolo SPI se realiza adecuadamente.

---

# Casos de prueba

## Caso 1: Master a Slave
El master envía un byte al slave a través de **MOSI**. El slave recibe los 8 bits usando el reloj **SCLK** y al finalizar la transferencia guarda el dato en `data_out` y activa la señal `done`.

## Caso 2: Slave a Master
El slave carga un byte en `data_in` y lo transmite al master mediante **MISO** mientras el master genera el reloj SPI. El master captura los bits recibidos y almacena el resultado en `data_out`.

## Caso 3: Transferencia simultánea (Full-Duplex)
El master y el slave cargan datos diferentes y realizan una transferencia SPI completa. Durante los 8 ciclos de **SCLK**, ambos dispositivos envían y reciben bits al mismo tiempo, verificando el funcionamiento **full-duplex** del protocolo.