module spi_slave (
	input  wire sclk, // Clk tipico
	input  wire ss, // Slave Select (Activo en bajo)
	input  wire mosi, // Master Out Slave In
	output wire miso, // Master In Slave Out, este es wire porque usamos solamente un assign
	input  wire[7:0] data_in, // Dato paralelo a enviar
	output reg [7:0] data_out, // Dato paralelo recibido, se usa reg porque queremos almacenar el dato, hasta el siguiente clk
	output reg done // Indica que ya termino, cambia dentro del clk, por eso es reg
);

reg [7:0] shift_reg;
reg [2:0] bit_cnt;

// Asignamos el bit mas significativo a MISO
assign miso = shift_reg[7];

always @(posedge sclk or posedge ss) begin
	if (ss) begin
	// Cuando no esta seleccionado, cargamos el dato a enviar
		shift_reg <= data_in;
		bit_cnt   <= 3'b000; // El contador lo inicializamos en 0
		done      <= 1'b0; //Para avisar que ya leimos el dato
	end else begin
		// En cada flanco de subida de SCLK
		// Desplazamos y capturamos MOSI
		shift_reg <= {shift_reg[6:0], mosi}; 
		// Agarramos los primeros 7 bits de la derecha
		// y los recorremos 1 bit a la izquierda para meter el siguiente
		// Al estar recorriendo shift_reg, va a enviar por medio de miso al mismo tiempo
		//Logica de conteo
		if (bit_cnt == 3'b111) begin // Cuando ya son 8 datos
			data_out <= {shift_reg[6:0], mosi}; // Guardamos el resultado final
			done     <= 1'b1; // Avisamos que ya termino
			bit_cnt  <= 3'b000; // Reset contador
		end else begin
			bit_cnt  <= bit_cnt + 1'b1; // Aumentamos contador
			done     <= 1'b0; // Todavia no esta listo
		end
	end
end
endmodule