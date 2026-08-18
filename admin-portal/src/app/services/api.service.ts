import { Injectable, inject } from "@angular/core";
import { HttpClient } from "@angular/common/http";
import { Observable } from "rxjs";
import { environment } from '../../environments/environment';

@Injectable({ providedIn: "root" })
export class ApiService {
  private http = inject(HttpClient);

  /**
   * In production the admin portal is served by nginx (same origin as the
   * sub-domain request, e.g. yogasree.placements.com), so we use
   * window.location.origin to keep requests on the correct tenant host.
   * In local dev the backend runs on a separate port (localhost:8080).
   */
  private get baseUrl(): string {
    return environment.production ? window.location.origin : 'http://localhost:8080';
  }

  get<T>(endpoint: string): Observable<T> {
    return this.http.get<T>(`${this.baseUrl}${endpoint}`);
  }

  post<T>(endpoint: string, data: any): Observable<T> {
    return this.http.post<T>(`${this.baseUrl}${endpoint}`, data);
  }

  put<T>(endpoint: string, data: any): Observable<T> {
    return this.http.put<T>(`${this.baseUrl}${endpoint}`, data);
  }

  delete<T>(endpoint: string): Observable<T> {
    return this.http.delete<T>(`${this.baseUrl}${endpoint}`);
  }

  postForm<T>(endpoint: string, formData: FormData): Observable<T> {
    return this.http.post<T>(`${this.baseUrl}${endpoint}`, formData);
  }
}
