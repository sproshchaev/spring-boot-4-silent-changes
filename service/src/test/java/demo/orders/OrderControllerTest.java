package demo.orders;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(OrderController.class)
class OrderControllerTest {

    @Autowired
    private MockMvc mvc;

    @MockBean
    private OrderRepository orders;

    private static OrderEntity sample() {
        return new OrderEntity("A-100", OrderStatus.PAID, new BigDecimal("1500.00"),
                Instant.parse("2026-10-01T09:00:00Z"));
    }

    @Test
    void listReturnsOrders() throws Exception {
        when(orders.findAll()).thenReturn(List.of(sample()));

        mvc.perform(get("/api/orders"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].sku").value("A-100"));
    }

    @Test
    void createReturnsCreated() throws Exception {
        when(orders.save(any())).thenAnswer(call -> call.getArgument(0));

        mvc.perform(post("/api/orders")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"sku":"B-200","price":1000.00,"discountPercent":10}
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.sku").value("B-200"));
    }
}
