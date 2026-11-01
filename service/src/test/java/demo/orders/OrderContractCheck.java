package demo.orders;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
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

/**
 * Positive control. The surefire name pattern skips this class, so a plain "mvn verify" stays
 * as shallow as OrderControllerTest. run.sh starts it with -Dtest=OrderContractCheck.
 */
@WebMvcTest(OrderController.class)
class OrderContractCheck {

    @Autowired
    private MockMvc mvc;

    @MockBean
    private OrderRepository orders;

    @Test
    void responseBodyIsExact() throws Exception {
        when(orders.findAll()).thenReturn(List.of(new OrderEntity("A-100", OrderStatus.PAID,
                new BigDecimal("1500.00"), Instant.parse("2026-10-01T09:00:00Z"))));

        mvc.perform(get("/api/orders"))
                .andExpect(status().isOk())
                .andExpect(content().string("""
                        [{"sku":"A-100","status":"PAID","total":"1500.00","createdAt":"2026-10-01T09:00:00Z"}]"""));
    }

    @Test
    void nullDiscountIsAccepted() throws Exception {
        when(orders.save(any())).thenAnswer(call -> call.getArgument(0));

        mvc.perform(post("/api/orders")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"sku":"B-201","price":1000.00,"discountPercent":null}
                                """))
                .andExpect(status().isCreated());
    }
}
