module spi_master (
    input  wire       clk,        // Reloj del sistema
    input  wire       rst,        // Reset activo en alto
    input  wire       start,      // Pulso para iniciar transferencia
    input  wire [7:0] data_in,    // Dato a enviar al esclavo (via MOSI)
    output reg  [7:0] data_out,   // Dato recibido del esclavo (via MISO)
    output reg        done,       // Indica que la transferencia terminó
    output reg        busy,       // Indica que el master está ocupado

    // Señales SPI hacia el esclavo
    output reg        sclk,       // Reloj SPI generado por el master
    output reg        ss,         // Slave Select (activo en bajo)
    output reg        mosi,       // Master Out Slave In
    input  wire       miso        // Master In Slave Out
);

// Parámetros
// Divisor de reloj genera SCLK a clk/2 por default.

// SCLK_freq = clk_freq / (2 * CLK_DIV)
parameter CLK_DIV = 1; // Con CLK_DIV=1 → SCLK = clk/2

// Registros internos
reg [7:0] shift_reg;          // Registro de desplazamiento TX
reg [7:0] capture_reg;        // Registro de captura RX
reg [2:0] bit_cnt;            // Contador de bits (0-7)
reg [$clog2(CLK_DIV)-1:0] clk_div_cnt; // Contador divisor de clk (solo si CLK_DIV > 1)

// FSM
localparam IDLE     = 2'd0;
localparam ASSERT   = 2'd1; // Activa SS y prepara datos
localparam TRANSFER = 2'd2; // Transfiere los 8 bits
localparam FINISH   = 2'd3; // Deactiva SS, señaliza done

reg [1:0] state;
reg       sclk_en;  // Habilita la generación de SCLK

// Generación de SCLK (toggle cuando sclk_en está activo)
// Para CLK_DIV = 1: SCLK cambia cada ciclo de clk del sistema

generate
    if (CLK_DIV == 1) begin : gen_sclk_div1
        always @(posedge clk or posedge rst) begin
            if (rst)
                sclk <= 1'b0;
            else if (sclk_en)
                sclk <= ~sclk;
            else
                sclk <= 1'b0;
        end
    end else begin : gen_sclk_divN
        always @(posedge clk or posedge rst) begin
            if (rst) begin
                sclk        <= 1'b0;
                clk_div_cnt <= 0;
            end else if (sclk_en) begin
                if (clk_div_cnt == CLK_DIV - 1) begin
                    sclk        <= ~sclk;
                    clk_div_cnt <= 0;
                end else begin
                    clk_div_cnt <= clk_div_cnt + 1;
                end
            end else begin
                sclk        <= 1'b0;
                clk_div_cnt <= 0;
            end
        end
    end
endgenerate

// FSM principal — sincronizada al flanco de bajada de SCLK
// para que el esclavo capture en flanco de subida (CPOL=0, CPHA=0)

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state       <= IDLE;
        ss          <= 1'b1;   // SS desactivado (alto)
        mosi        <= 1'b0;
        done        <= 1'b0;
        busy        <= 1'b0;
        sclk_en     <= 1'b0;
        bit_cnt     <= 3'd0;
        shift_reg   <= 8'd0;
        capture_reg <= 8'd0;
        data_out    <= 8'd0;
    end else begin
        done <= 1'b0; // done es un pulso de 1 ciclo

        case (state)

            IDLE: begin
                ss      <= 1'b1;
                sclk_en <= 1'b0;
                busy    <= 1'b0;
                if (start) begin
                    shift_reg <= data_in; // Cargamos dato a enviar
                    bit_cnt   <= 3'd0;
                    state     <= ASSERT;
                    busy      <= 1'b1;
                end
            end

            // Activamos SS (bajo) antes del primer flanco de SCLK
            // El esclavo usa SS=1 como reset, así que lo bajamos aquí
            ASSERT: begin
                ss      <= 1'b0;      // Seleccionamos esclavo
                mosi    <= data_in[7]; // Precargamos el MSB
                shift_reg <= data_in;
                sclk_en <= 1'b1;      // Arrancamos SCLK
                state   <= TRANSFER;
            end

            // Transferencia: en cada flanco de BAJADA de SCLK
            // actualizamos MOSI (el esclavo captura en subida)
            // y capturamos MISO.
            TRANSFER: begin
                // Actuamos en flanco de bajada de SCLK
                if (sclk == 1'b1) begin  // Esperamos que SCLK baje
                    // En el siguiente ciclo SCLK bajará: preparamos MOSI
                end else begin
                    // SCLK está bajo: actualizamos MOSI con el siguiente bit
                    // y capturamos el bit recibido en MISO
                    capture_reg <= {capture_reg[6:0], miso}; // Shift-in MISO

                    if (bit_cnt == 3'd7) begin
                        // Último bit transferido
                        data_out <= {capture_reg[6:0], miso};
                        sclk_en  <= 1'b0;
                        state    <= FINISH;
                    end else begin
                        // Preparamos el siguiente bit en MOSI
                        bit_cnt   <= bit_cnt + 1'b1;
                        shift_reg <= {shift_reg[6:0], 1'b0};
                        mosi      <= shift_reg[6]; // Próximo MSB
                    end
                end
            end

            FINISH: begin
                ss    <= 1'b1;  // Deessseleccionamos esclavo
                mosi  <= 1'b0;
                done  <= 1'b1;  // Pulso de done
                busy  <= 1'b0;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule