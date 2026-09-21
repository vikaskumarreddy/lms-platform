package com.institute.lms.controller;

import com.institute.lms.entity.Organization;
import com.institute.lms.entity.StudyTopic;
import com.institute.lms.entity.User;
import com.institute.lms.repository.StudyTopicRepository;
import com.institute.lms.util.OrganizationContext;
import com.institute.lms.util.UserContext;
import org.junit.jupiter.api.*;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import java.util.List;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class StudyTopicControllerTest {
    private final StudyTopicRepository repository = mock(StudyTopicRepository.class);
    private final UserContext users = mock(UserContext.class);
    private final OrganizationContext tenants = new OrganizationContext();
    private MockMvc mvc;

    @BeforeEach void setup() {
        Organization org = new Organization();
        org.setId(3L);
        tenants.setCurrentOrganization(org);
        User user = new User();
        user.setId(7L);
        user.setOrganizationId(3L);
        when(users.currentUser()).thenReturn(user);
        mvc = MockMvcBuilders.standaloneSetup(new StudyTopicController(repository, users)).build();
    }

    @AfterEach void clearTenant() { tenants.clear(); }

    @Test void createUsesAuthenticatedOwnerAndTrimsTitle() throws Exception {
        when(repository.save(any())).thenAnswer(invocation -> {
            StudyTopic topic = invocation.getArgument(0);
            Assertions.assertEquals(7L, topic.getUserId());
            topic.setId(12L);
            return topic;
        });
        mvc.perform(post("/api/study-topics").contentType(MediaType.APPLICATION_JSON)
                .content("{\"title\":\"  Flutter basics  \",\"userId\":999}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.title").value("Flutter basics"))
                .andExpect(jsonPath("$.userId").value(7));
    }

    @Test void listOnlyQueriesAuthenticatedOwner() throws Exception {
        when(repository.findByUserIdOrderByUpdatedAtDescIdDesc(7L)).thenReturn(List.of());
        mvc.perform(get("/api/study-topics")).andExpect(status().isOk())
                .andExpect(content().json("[]"));
        verify(repository).findByUserIdOrderByUpdatedAtDescIdDesc(7L);
    }

    @Test void invalidTitlesAreRejectedWithoutWrites() throws Exception {
        for (String title : List.of("", "   ", "a".repeat(201))) {
            mvc.perform(post("/api/study-topics").contentType(MediaType.APPLICATION_JSON)
                    .content("{\"title\":\"" + title + "\"}"))
                    .andExpect(status().isBadRequest());
        }
        mvc.perform(post("/api/study-topics").contentType(MediaType.APPLICATION_JSON)
                .content("{}" )).andExpect(status().isBadRequest());
        verifyNoInteractions(repository);
    }

    @Test void unauthenticatedAccessIsRejected() throws Exception {
        when(users.currentUser()).thenReturn(null);
        mvc.perform(get("/api/study-topics")).andExpect(status().isUnauthorized());
        mvc.perform(post("/api/study-topics").contentType(MediaType.APPLICATION_JSON)
                .content("{\"title\":\"Topic\"}")).andExpect(status().isUnauthorized());
        verifyNoInteractions(repository);
    }

    @Test void mismatchedTenantIsRejected() throws Exception {
        tenants.clear();
        mvc.perform(get("/api/study-topics")).andExpect(status().isForbidden());
        mvc.perform(post("/api/study-topics").contentType(MediaType.APPLICATION_JSON)
                .content("{\"title\":\"Topic\"}")).andExpect(status().isForbidden());
        verifyNoInteractions(repository);
    }
}
